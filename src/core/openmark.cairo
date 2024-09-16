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
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::traits::Into;
    use core::array::SpanTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use starknet::{
        get_caller_address, get_contract_address, get_tx_info, ContractAddress, get_block_timestamp,
    };
    use starknet::ClassHash;

    use core::num::traits::Zero;
    use core::panic_with_felt252;

    use openmark::primitives::types::{Order, OrderType, Bid, SignedBid, Bag};
    use openmark::hasher::interface::IOffchainMessageHash;
    use openmark::hasher::{HasherComponent};
    use openmark::core::interface::{
        IOpenMark, IOpenMarkCamel, IOpenMarkProvider, IOpenMarkProviderCamel, IOpenMarkManager
    };
    use openmark::core::events::{OrderFilled, OrderCancelled, BidCancelled, BidFilled};
    use openmark::core::errors::OMErrors as Errors;
    use openmark::primitives::utils::{
        nft_transfer_from, payment_transfer_from, payment_balance_of, nft_owner_of
    };

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
        /// hash provider
        #[substorage(v0)]
        hasher: HasherComponent::Storage,
        /// OpenMark's commission (per mille)
        commission: u32,
        /// Maximum number of tokens that can be handled in a single fillBids operation
        maxBidNFTs: u32,
        /// store used order signatures
        usedSignatures: starknet::storage::Map<felt252, bool>,
        /// store partial bid signatures
        partialBidSignatures: starknet::storage::Map<felt252, u128>,
        /// store allowed payment tokens
        paymentTokens: starknet::storage::Map<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, paymentToken: ContractAddress) {
        self.ownable.initializer(owner);
        self.paymentTokens.write(paymentToken, true);
        self.commission.write(0);
        self.maxBidNFTs.write(10);
    }

    #[abi(embed_v0)]
    impl OpenMarkImpl of IOpenMark<ContractState> {
        fn buy(
            ref self: ContractState, seller: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            self.reentrancy_guard.start();
            let buyer = get_caller_address();

            self.verify_buy(order, signature, seller, buyer);

            // 3. make trade
            nft_transfer_from(order.nftContract, seller, buyer, order.tokenId.into());

            let price: u256 = order.price.into();
            self._process_payment(buyer, seller, price, order.payment);

            // 4. change storage
            self.usedSignatures.write(self.hash_array(signature), true);

            // 5. emit events
            self.emit(OrderFilled { seller, buyer, order });
            self.reentrancy_guard.end();
        }

        fn accept_offer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            self.reentrancy_guard.start();
            let seller = get_caller_address();

            self.verify_accept_offer(order, signature, seller, buyer);

            // 3. make trade
            nft_transfer_from(
                order.nftContract, get_caller_address(), buyer, order.tokenId.into()
            );

            let price: u256 = order.price.into();
            self._process_payment(buyer, get_caller_address(), price, order.payment);

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

            let seller = get_caller_address();

            if let Result::Err(err) = self._verify_bid_seller(seller, nft_token, token_ids) {
                panic_with_felt252(err);
            }

            let valid_bids = self.get_valid_bids(bids, nft_token, payment_token, asking_price);

            assert(valid_bids.len() > 0, Errors::NO_VALID_BIDS);

            let mut trade_token_ids = token_ids;
            let mut i = 0;
            while (i < valid_bids.len() && trade_token_ids.len() > 0) {
                self._process_bid(seller, *valid_bids.at(i), ref trade_token_ids);
                i += 1;
            };

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
            for bag in bags {
                self.buy(*bag.seller, *bag.order, *bag.signature);
            }
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

        fn verify_buy(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
            seller: ContractAddress,
            buyer: ContractAddress
        ) {
            // 1. verify order
            self._verify_order(order, seller, get_caller_address(), OrderType::Buy);

            // 2. verify signature
            self._validate_order_signature(order, seller, signature);
        }

        fn verify_accept_offer(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
            seller: ContractAddress,
            buyer: ContractAddress
        ) {
            // 1. verify order
            self._verify_order(order, seller, buyer, OrderType::Offer);

            // 2. verify signature
            self._validate_order_signature(order, buyer, signature);
        }

        fn verify_signed_bid(self: @ContractState, bid: SignedBid) {
            if let Result::Err(err) = self._verify_signed_bid(bid) {
                panic_with_felt252(err);
            }
        }

        fn get_valid_bids(
            self: @ContractState,
            bids: Span<SignedBid>,
            nft_token: ContractAddress,
            payment_token: ContractAddress,
            asking_price: u128
        ) -> Span<SignedBid> {
            let mut valid_bids = ArrayTrait::new();

            for bid in bids {
                if let Result::Err(_) = self._verify_signed_bid(*bid) {
                    continue;
                };

                if let Result::Err(_) = self
                    ._verify_matching_bid(*bid.bid, nft_token, payment_token, asking_price) {
                    continue;
                }
                valid_bids.append(*bid);
            };

            valid_bids.span()
        }

        fn get_version(self: @ContractState) -> (u32, u32, u32) {
            // version 0.2.2
            (0, 2, 2)
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkProviderCamelImpl of IOpenMarkProviderCamel<ContractState> {
        fn getChainId(self: @ContractState) -> felt252 {
            self.get_chain_id()
        }
        fn getCommission(self: @ContractState) -> u32 {
            self.get_commission()
        }
        fn verifyPaymentToken(self: @ContractState, paymentToken: ContractAddress) -> bool {
            self.verify_payment_token(paymentToken)
        }
        fn isUsedSignature(self: @ContractState, signature: Span<felt252>) -> bool {
            self.is_used_signature(signature)
        }

        fn verifyBuy(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
            seller: ContractAddress,
            buyer: ContractAddress
        ) {
            self.verify_buy(order, signature, seller, buyer)
        }

        fn verifyAcceptOffer(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
            seller: ContractAddress,
            buyer: ContractAddress
        ) {
            self.verify_accept_offer(order, signature, seller, buyer)
        }

        fn verifySignedBid(self: @ContractState, bid: SignedBid) {
            self.verify_signed_bid(bid);
        }

        fn getValidBids(
            self: @ContractState,
            bids: Span<SignedBid>,
            nftToken: ContractAddress,
            paymentToken: ContractAddress,
            askingPrice: u128
        ) -> Span<SignedBid> {
            self.get_valid_bids(bids, nftToken, paymentToken, askingPrice)
        }

        fn getVersion(self: @ContractState) -> (u32, u32, u32) {
            self.get_version()
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

        fn set_max_fill_nfts(ref self: ContractState, max_nfts: u32) {
            self.ownable.assert_only_owner();
            self.maxBidNFTs.write(max_nfts);
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
        fn _validate_order_signature(
            self: @ContractState, order: Order, signer: ContractAddress, signature: Span<felt252>,
        ) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(!self.usedSignatures.read(self.hash_array(signature)), Errors::SIGNATURE_USED);
            assert(
                self.hasher.verify_order(order, signer.into(), signature), Errors::INVALID_SIGNATURE
            );
        }

        fn _verify_order(
            self: @ContractState,
            order: Order,
            seller: ContractAddress,
            buyer: ContractAddress,
            order_type: OrderType
        ) {
            assert(order.expiry > get_block_timestamp().into(), Errors::ORDER_EXPIRED);
            assert(order.option == order_type, Errors::INVALID_ORDER_TYPE);
            assert(self.verify_payment_token(order.payment), Errors::INVALID_PAYMENT_TOKEN);

            assert(!seller.is_zero(), Errors::ZERO_ADDRESS);
            assert(!buyer.is_zero(), Errors::ZERO_ADDRESS);

            assert(
                nft_owner_of(order.nftContract, order.tokenId.into()) == seller,
                Errors::NOT_NFT_OWNER
            );

            let price: u256 = order.price.into();

            assert(
                payment_balance_of(order.payment, buyer) >= price, Errors::INSUFFICIENT_BALANCE
            );

            assert(price > 0, Errors::PRICE_IS_ZERO);
        }

        fn _calculate_commission(self: @ContractState, price: u256) -> u256 {
            price * self.commission.read().into() / PERMYRIAD.into()
        }

        fn _verify_bid(
            self: @ContractState, bid: Bid, bidder: ContractAddress
        ) -> Result<(), felt252> {
            if bidder.is_zero() {
                return Result::Err(Errors::ZERO_ADDRESS);
            }

            if !self.verify_payment_token(bid.payment) {
                return Result::Err(Errors::INVALID_PAYMENT_TOKEN);
            }

            if bid.amount.is_zero() {
                return Result::Err(Errors::ZERO_BIDS_AMOUNT);
            }

            let price: u256 = (bid.unitPrice * bid.amount).into();

            if price.is_zero() {
                return Result::Err(Errors::PRICE_IS_ZERO);
            }

            if payment_balance_of(bid.payment, bidder) < price {
                return Result::Err(Errors::INSUFFICIENT_BALANCE);
            }

            if bid.expiry <= get_block_timestamp().into() {
                return Result::Err(Errors::BID_EXPIRED);
            }

            Result::Ok(())
        }

        fn _verify_signed_bid(self: @ContractState, bid: SignedBid) -> Result<(), felt252> {
            if let Result::Err(err) = self._verify_bid(bid.bid, bid.bidder) {
                return Result::Err(err);
            }

            if let Result::Err(err) = self
                ._verify_bid_signature(bid.bid, bid.bidder, bid.signature) {
                return Result::Err(err);
            }
            Result::Ok(())
        }

        fn _verify_matching_bid(
            self: @ContractState,
            bid: Bid,
            nft_token: ContractAddress,
            payment_token: ContractAddress,
            asking_price: u128
        ) -> Result<(), felt252> {
            if bid.nftContract != nft_token {
                return Result::Err(Errors::NFT_MISMATCH);
            }

            if bid.payment != payment_token {
                return Result::Err(Errors::PAYMENT_MISMATCH);
            }

            if asking_price > bid.unitPrice {
                return Result::Err(Errors::ASKING_PRICE_TOO_HIGH);
            }

            Result::Ok(())
        }

        fn _verify_bid_seller(
            self: @ContractState,
            seller: ContractAddress,
            nft_token: ContractAddress,
            token_ids: Span<u128>,
        ) -> Result<(), felt252> {
            if token_ids.is_empty() {
                return Result::Err(Errors::ZERO_NFTS);
            }

            if seller.is_zero() {
                return Result::Err(Errors::ZERO_ADDRESS);
            }

            if token_ids.len() >= self.maxBidNFTs.read() {
                return Result::Err(Errors::TOO_MANY_NFTS);
            }

            let mut is_owner = true;
            for token_id in token_ids {
                if nft_owner_of(nft_token, (*token_id).into()) != seller {
                    is_owner = false;
                    break;
                }
            };

            if !is_owner {
                return Result::Err(Errors::NOT_NFT_OWNER);
            }

            Result::Ok(())
        }


        fn _verify_bid_signature(
            self: @ContractState, bid: Bid, signer: ContractAddress, signature: Span<felt252>,
        ) -> Result<(), felt252> {
            if signature.len() != 2 {
                return Result::Err(Errors::INVALID_SIGNATURE_LEN);
            }

            let is_used = self.usedSignatures.read(self.hasher.hash_array(signature));
            if is_used {
                return Result::Err(Errors::SIGNATURE_USED);
            }

            if !self.hasher.verify_bid(bid, signer.into(), signature) {
                return Result::Err(Errors::INVALID_SIGNATURE);
            }

            Result::Ok(())
        }


        fn _process_bid(
            ref self: ContractState,
            seller: ContractAddress,
            signed_bid: SignedBid,
            ref trade_token_ids: Span<u128>
        ) {
            let signature = self.hash_array(signed_bid.signature);
            let mut bid_amount = signed_bid.bid.amount;
            let mut trade_amount: u128 = trade_token_ids.len().into();
            let mut remaining_amount: u128 = 0;
            {
                let partial_amount = self.partialBidSignatures.read(signature);
                if partial_amount > 0 {
                    bid_amount = partial_amount;
                }

                if (trade_amount > bid_amount) {
                    trade_amount = bid_amount;
                } else {
                    remaining_amount = bid_amount - trade_amount;
                }
            }

            let price: u256 = (signed_bid.bid.unitPrice * trade_amount).into();
            self
                ._process_payment(
                    signed_bid.bidder, get_caller_address(), price, signed_bid.bid.payment
                );

            let mut traded_ids = ArrayTrait::new();
            let mut token_index: u128 = 0;

            while (token_index < trade_amount) {
                let token_id: u128 = *trade_token_ids.pop_front().unwrap();

                nft_transfer_from(
                    signed_bid.bid.nftContract, seller, signed_bid.bidder, token_id.into()
                );

                traded_ids.append(token_id);
                token_index += 1;
            };

            if remaining_amount > 0 {
                self.partialBidSignatures.write(signature, remaining_amount);
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

        /// Processes a payment from sender to a receiver.
        ///
        /// # Parameters:
        /// - `sender`: The sender address.
        /// - `receiver`: The address to receive the payment.
        /// - `amount`: The amount to be transferred.
        /// - `payment_token`: The address of the payment token contract.
        fn _process_payment(
            self: @ContractState,
            sender: ContractAddress,
            receiver: ContractAddress,
            amount: u256,
            payment_token: ContractAddress
        ) {
            let commission = self._calculate_commission(amount);
            let payout = amount - commission;

            payment_transfer_from(payment_token, sender, receiver, payout);

            if commission > 0 {
                payment_transfer_from(payment_token, sender, get_contract_address(), commission);
            }
        }
    }
}
