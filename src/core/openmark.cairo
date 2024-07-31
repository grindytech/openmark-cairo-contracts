// SPDX-License-Identifier: MIT
// OpenMark Contracts for Cairo

/// # OpenMark Contract
///
/// # This contract implements the OpenMark NFT marketplace on StarkNet, allowing users to:
/// - Buy: Purchase listed NFTs directly from sellers.
/// - Sell: List NFTs for sale with desired prices.
/// - Bid: Place competitive bids on listed NFTs.
/// - Auction: Conduct auctions where NFTs are sold to the highest bidder.
/// - Random NFT Mining: Engage in random NFT mining for discovery.

#[starknet::contract]
pub mod OpenMark {
    // use core::option::OptionTrait;
    use core::option::OptionTrait;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use core::traits::Into;
    use core::array::SpanTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::utils::{try_selector_with_fallback};
    use openzeppelin::utils::selectors;
    use openzeppelin::utils::UnwrapAndCast;

    use starknet::{
        get_caller_address, get_contract_address, get_tx_info, ContractAddress, get_block_timestamp,
    };
    use starknet::ClassHash;
    use starknet::SyscallResultTrait;
    use starknet::syscalls::call_contract_syscall;

    use core::num::traits::Zero;

    use openmark::primitives::types::{Order, OrderType, IStructHash, Bid, SignedBid, Bag};
    use openmark::hasher::interface::IOffchainMessageHash;
    use openmark::hasher::{HasherComponent};
    use openmark::core::interface::{IOpenMark, IOpenMarkCamel, IOpenMarkProvider, IOpenMarkManager};
    use openmark::core::events::{OrderFilled, OrderCancelled, BidCancelled, BidFilled};
    use openmark::core::errors as Errors;

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
    );
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    /// Hasher
    component!(path: HasherComponent, storage: hasher, event: HasherEvent);

    #[abi(embed_v0)]
    /// Ownable
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    /// Reentrancy
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    /// Hasher
    impl HasherImpl = HasherComponent::HasherImpl<ContractState>;

    const MAX_COMMISSION: u32 = 500; // per mille (fixed 50%)
    const PERMYRIAD: u32 = 1000;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        HasherEvent: HasherComponent::Event,
        OrderFilled: OrderFilled,
        OrderCancelled: OrderCancelled,
        BidFilled: BidFilled,
        BidCancelled: BidCancelled,
    }


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        hasher: HasherComponent::Storage, // hash provider
        // OpenMark's commission (per mille)
        commission: u32,
        // Maximum number of bids allowed in fillBids
        maxFillBids: u32,
        // Maximum number of tokens that can be handled in a single fillBids operation
        maxFillNFTs: u32,
        usedSignatures: LegacyMap<felt252, bool>, // store used order signatures
        partialBidSignatures: LegacyMap<felt252, u128>, // store partial bid signatures
        paymentTokens: LegacyMap<ContractAddress, bool>, // store allowed payment tokens
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, paymentToken: ContractAddress) {
        self.ownable.initializer(owner);
        self.paymentTokens.write(paymentToken, true);
        self.commission.write(0);
        self.maxFillBids.write(5);
        self.maxFillNFTs.write(10);
    }


    #[abi(embed_v0)]
    impl OpenMarkImpl of IOpenMark<ContractState> {
        fn buy(
            ref self: ContractState, seller: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            self.reentrancy_guard.start();

            // 1. verify signature
            self.validate_order_signature(order, seller, signature);

            // 2. verify order
            self.validate_order(order, seller, get_caller_address(), OrderType::Buy);

            // 3. make trade
            self
                .nft_transfer_from(
                    order.nftContract, seller, get_caller_address(), order.tokenId.into()
                );

            let price: u256 = order.price.into();
            self.process_payment(get_caller_address(), seller, price, order.payment);

            // 4. change storage
            self.usedSignatures.write(self.hash_array(signature), true);

            // 5. emit events
            self.emit(OrderFilled { seller, buyer: get_caller_address(), order });
            self.reentrancy_guard.end();
        }

        fn accept_offer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            self.reentrancy_guard.start();
            // 1. verify signature
            self.validate_order_signature(order, buyer, signature);

            // 2. verify order
            self.validate_order(order, get_caller_address(), buyer, OrderType::Offer);

            // 3. make trade
            self
                .nft_transfer_from(
                    order.nftContract, get_caller_address(), buyer, order.tokenId.into()
                );

            let price: u256 = order.price.into();
            self.process_payment(buyer, get_caller_address(), price, order.payment);

            // 4. change storage
            self.usedSignatures.write(self.hash_array(signature), true);
            // 5. emit events
            self.emit(OrderFilled { seller: get_caller_address(), buyer, order });
            self.reentrancy_guard.end();
        }

        fn fill_bids(
            ref self: ContractState,
            bids: Span<SignedBid>,
            nft_token: ContractAddress,
            token_ids: Span<u128>,
            payment_token: ContractAddress,
            asking_price: u128,
        ) {
            self.reentrancy_guard.start();

            // 1. Verify signatures
            let state = @self;
            {
                let mut i = 0;
                while (i < bids.len()) {
                    let signed_bid = *bids.at(i);
                    state
                        .validate_bid_signature(
                            signed_bid.bid, signed_bid.bidder, signed_bid.signature
                        );
                    i += 1;
                };
            }

            // 2. Validate Bids
            self.validate_bids(bids);

            //2.1 Validate Supply
            self
                .validate_bid_supply(
                    bids, get_caller_address(), nft_token, token_ids, payment_token, asking_price
                );

            // 3. calculate and validate bid amounts
            let total_bid_amount = self.validate_bid_amounts(bids, token_ids);

            // 4. process bid transactions
            self.process_all_bids(bids, token_ids, total_bid_amount);

            self.reentrancy_guard.end();
        }

        fn cancel_order(ref self: ContractState, order: Order, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(!self.usedSignatures.read(self.hash_array(signature)), Errors::SIGNATURE_USED);

            assert(
                self.hasher.verify_order(order, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedSignatures.write(self.hash_array(signature), true);

            self.emit(OrderCancelled { who: get_caller_address(), order, });
        }

        fn cancel_bid(ref self: ContractState, bid: Bid, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(!self.usedSignatures.read(self.hash_array(signature)), Errors::SIGNATURE_USED);

            assert(
                self.hasher.verify_bid(bid, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedSignatures.write(self.hash_array(signature), true);
            self.emit(BidCancelled { who: get_caller_address(), bid, });
        }

        fn batch_buy(ref self: ContractState, bags: Span<Bag>) {
            let mut i = 0;
            while (i < bags.len()) {
                let bag = *bags.at(i);
                self.buy(bag.seller, bag.order, bag.signature);
            };
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkCamelImpl of IOpenMarkCamel<ContractState> {
        fn acceptOffer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            self.accept_offer(buyer, order, signature);
        }

        fn fillBids(
            ref self: ContractState,
            bids: Span<SignedBid>,
            nftContract: ContractAddress,
            tokenIds: Span<u128>,
            paymentToken: ContractAddress,
            askingPrice: u128,
        ) {
            self.fill_bids(bids, nftContract, tokenIds, paymentToken, askingPrice);
        }

        fn cancelOrder(ref self: ContractState, order: Order, signature: Span<felt252>) {
            self.cancel_order(order, signature);
        }

        fn cancelBid(ref self: ContractState, bid: Bid, signature: Span<felt252>) {
            self.cancel_bid(bid, signature);
        }

        fn batchBuy(ref self: ContractState, bags: Span<Bag>) {
            self.batch_buy(bags);
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkProviderImpl of IOpenMarkProvider<ContractState> {
        fn get_chain_id(self: @ContractState) -> felt252 {
            get_tx_info().unbox().chain_id
        }

        fn get_commission(self: @ContractState) -> u32 {
            self.commission.read()
        }

        fn verify_payment_token(self: @ContractState, payment_token: ContractAddress) -> bool {
            self.paymentTokens.read(payment_token)
        }

        fn is_used_signature(self: @ContractState, signature: Span<felt252>) -> bool {
            self.usedSignatures.read(self.hash_array(signature))
        }

        fn validate_order(
            self: @ContractState,
            order: Order,
            seller: ContractAddress,
            buyer: ContractAddress,
            order_type: OrderType
        ) {
            assert(order.expiry > get_block_timestamp().into(), Errors::SIGNATURE_EXPIRED);
            assert(order.option == order_type, Errors::INVALID_ORDER_TYPE);

            assert(!seller.is_zero(), Errors::ZERO_ADDRESS);
            assert(!buyer.is_zero(), Errors::ZERO_ADDRESS);

            assert(
                self.nft_owner_of(order.nftContract, order.tokenId.into()) == seller,
                Errors::SELLER_NOT_OWNER
            );

            let price: u256 = order.price.into();
            assert(price > 0, Errors::PRICE_IS_ZERO);
        }

        fn validate_bids(self: @ContractState, bids: Span<SignedBid>) {
            assert(bids.len() > 0, Errors::NO_BIDS);
            assert(bids.len() < self.maxFillBids.read(), Errors::TOO_MANY_BIDS);
            {
                let mut i = 0;
                while (i < bids.len()) {
                    let signed_bid = *bids.at(i);
                    assert(!signed_bid.bidder.is_zero(), Errors::ZERO_ADDRESS);
                    let bid = signed_bid.bid;

                    assert(bid.amount > 0, Errors::ZERO_BIDS_AMOUNT);
                    assert(bid.unitPrice > 0, Errors::PRICE_IS_ZERO);
                    assert(bid.expiry > get_block_timestamp().into(), Errors::SIGNATURE_EXPIRED);
                    i += 1;
                };
            }
        }

        fn validate_bid_supply(
            self: @ContractState,
            bids: Span<SignedBid>,
            seller: ContractAddress,
            nft_token: ContractAddress,
            token_ids: Span<u128>,
            payment_token: ContractAddress,
            asking_price: u128
        ) {
            {
                let mut i = 0;
                while (i < bids.len()) {
                    let bid = (*bids.at(i)).bid;
                    assert(bid.nftContract == nft_token, Errors::NFT_MISMATCH);
                    assert(bid.payment == payment_token, Errors::PAYMENT_MISMATCH);
                    assert(asking_price <= bid.unitPrice, Errors::ASKING_PRICE_TOO_HIGH);

                    i += 1;
                };
            }
            assert(token_ids.len() < self.maxFillNFTs.read(), Errors::TOO_MANY_NFTS);
            {
                let mut i = 0;
                while (i < token_ids.len()) {
                    assert(
                        self.nft_owner_of(nft_token, (*token_ids.at(i)).into()) == seller,
                        Errors::SELLER_NOT_OWNER
                    );

                    i += 1;
                };
            }
        }

        fn validate_bid_signature(
            self: @ContractState, bid: Bid, signer: ContractAddress, signature: Span<felt252>,
        ) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            let is_used = self.usedSignatures.read(self.hasher.hash_array(signature));
            assert(!is_used, Errors::SIGNATURE_USED);
            assert(
                self.hasher.verify_bid(bid, signer.into(), signature), Errors::INVALID_SIGNATURE
            );
        }

        fn validate_order_signature(
            self: @ContractState, order: Order, signer: ContractAddress, signature: Span<felt252>,
        ) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(!self.usedSignatures.read(self.hash_array(signature)), Errors::SIGNATURE_USED);
            assert(
                self.hasher.verify_order(order, signer.into(), signature), Errors::INVALID_SIGNATURE
            );
        }

        fn validate_bid_amounts(
            self: @ContractState, bids: Span<SignedBid>, tokenIds: Span<u128>,
        ) -> u128 {
            let mut min_bid_amount = 0;
            let mut total_bid_amount = 0;
            {
                let mut i = 0;
                while (i < bids.len()) {
                    let bid = (*bids.at(i)).bid;
                    let signature = self.hash_array((*bids.at(i)).signature);

                    let mut amount = bid.amount;
                    {
                        let partial_signature_amount = self.partialBidSignatures.read(signature);
                        if partial_signature_amount > 0 {
                            amount = partial_signature_amount;
                        }
                    }

                    total_bid_amount += amount;
                    if i < bids.len() - 1 {
                        min_bid_amount += amount;
                    }

                    i += 1;
                };
            }

            assert(tokenIds.len().into() <= total_bid_amount, Errors::EXCEED_BID_NFTS);
            assert(tokenIds.len().into() > min_bid_amount, Errors::NOT_ENOUGH_BID_NFTS);

            total_bid_amount
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkManagerImpl of IOpenMarkManager<ContractState> {
        fn set_commission(ref self: ContractState, new_commission: u32) {
            self.ownable.assert_only_owner();
            assert(new_commission < MAX_COMMISSION, Errors::COMMISSION_TOO_HIGH);
            self.commission.write(new_commission);
        }

        fn add_payment_token(ref self: ContractState, payment_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.paymentTokens.write(payment_token, true);
        }
        fn remove_payment_token(ref self: ContractState, payment_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.paymentTokens.write(payment_token, false);
        }

        fn set_max_fill_bids(ref self: ContractState, max_bids: u32) {
            self.ownable.assert_only_owner();
            self.maxFillBids.write(max_bids);
        }
        fn set_max_fill_nfts(ref self: ContractState, max_nfts: u32) {
            self.ownable.assert_only_owner();
            self.maxFillNFTs.write(max_nfts);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalImplTrait {
        fn calculate_commission(self: @ContractState, price: u256) -> u256 {
            price * self.commission.read().into() / PERMYRIAD.into()
        }

        fn process_bid(
            ref self: ContractState,
            seller: ContractAddress,
            signed_bid: SignedBid,
            ref trade_token_ids: Span<u128>,
            remaining_amount: Option<u128>
        ) {
            let signature = self.hash_array(signed_bid.signature);
            let mut amount = signed_bid.bid.amount;

            let partial_signature_amount = self.partialBidSignatures.read(signature);
            if partial_signature_amount > 0 {
                amount = partial_signature_amount;
            }

            if let Option::Some(rem_amount) = remaining_amount {
                amount -= rem_amount;
            }

            let price: u256 = (signed_bid.bid.unitPrice * amount).into();
            self
                .process_payment(
                    signed_bid.bidder, get_caller_address(), price, signed_bid.bid.payment
                );

            let mut traded_ids = ArrayTrait::new();
            let mut token_index: u128 = 0;
            let state = @self;

            while (token_index < amount) {
                let token_id: u128 = *trade_token_ids.pop_front().unwrap();

                state
                    .nft_transfer_from(
                        signed_bid.bid.nftContract, seller, signed_bid.bidder, token_id.into()
                    );

                traded_ids.append(token_id);
                token_index += 1;
            };

            if let Option::Some(rem_amount) = remaining_amount {
                self.partialBidSignatures.write(signature, rem_amount);
            } else {
                self.usedSignatures.write(signature, true);
                self.partialBidSignatures.write(signature, 0);
            }

            self
                .emit(
                    BidFilled {
                        seller,
                        bidder: signed_bid.bidder,
                        bid: signed_bid.bid,
                        tokenIds: traded_ids.span(),
                    }
                );
        }

        fn process_all_bids(
            ref self: ContractState,
            bids: Span<SignedBid>,
            tokenIds: Span<u128>,
            total_bid_amount: u128
        ) {
            let mut maybe_remaining: Option<u128> = Option::None;
            let remaining_amount = total_bid_amount - tokenIds.len().into();
            if remaining_amount > 0 {
                maybe_remaining = Option::Some(remaining_amount);
            }

            let mut trade_token_ids = tokenIds;

            // wholesale
            let mut i = 0;
            while (i < bids.len() - 1) {
                self
                    .process_bid(
                        get_caller_address(), *bids.at(i), ref trade_token_ids, Option::None
                    );
                i += 1;
            };

            // partial sale
            let signed_bid = *bids.at(bids.len() - 1);
            self
                .process_bid(
                    get_caller_address(), signed_bid, ref trade_token_ids, maybe_remaining
                );
        }

        /// Processes a payment from sender to a receiver.
        /// 
        /// # Parameters:
        /// - `sender`: The sender address.
        /// - `receiver`: The address to receive the payment.
        /// - `amount`: The amount to be transferred.
        /// - `payment_token`: The address of the payment token contract.
        fn process_payment(
            self: @ContractState,
            sender: ContractAddress,
            receiver: ContractAddress,
            amount: u256,
            payment_token: ContractAddress
        ) {
            assert(self.verify_payment_token(payment_token), Errors::INVALID_PAYMENT_TOKEN);
            let commission = self.calculate_commission(amount);
            let payout = amount - commission;

            self.payment_transfer_from(payment_token, sender, receiver, payout);

            if commission > 0 {
                self
                    .payment_transfer_from(
                        payment_token, sender, get_contract_address(), commission
                    );
            }
        }

        fn payment_transfer_from(
            self: @ContractState,
            target: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            amount: u256
        ) {
            let mut args = array![];
            args.append_serde(sender);
            args.append_serde(receiver);
            args.append_serde(amount);

            try_selector_with_fallback(
                target, selectors::transfer_from, selectors::transferFrom, args.span()
            )
                .unwrap_syscall();
        }

        fn nft_transfer_from(
            self: @ContractState,
            target: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            token_id: u256
        ) {
            let mut args = array![];
            args.append_serde(sender);
            args.append_serde(receiver);
            args.append_serde(token_id);

            try_selector_with_fallback(
                target, selectors::transfer_from, selectors::transferFrom, args.span()
            )
                .unwrap_syscall();
        }

        fn nft_owner_of(
            self: @ContractState, target: ContractAddress, token_id: u256
        ) -> ContractAddress {
            let mut args = array![];
            args.append_serde(token_id);

            try_selector_with_fallback(target, selectors::owner_of, selectors::ownerOf, args.span())
                .unwrap_and_cast()
        }
    }
}
