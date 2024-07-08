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
    use core::option::OptionTrait;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use core::traits::Into;
    use core::array::SpanTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{
        IERC721, IERC721Dispatcher, IERC721DispatcherTrait
    };
    use starknet::{
        get_caller_address, get_contract_address, get_tx_info, ContractAddress, get_block_timestamp,
    };
    use core::num::traits::Zero;

    use openmark::primitives::{Order, OrderType, IStructHash, Bid, SignedBid};
    use openmark::interface::{IOpenMark, IOffchainMessageHash, IOpenMarkProvider, IOpenMarkManager};
    use openmark::hasher::HasherComponent;
    use openmark::events::{OrderFilled, OrderCancelled, BidsFilled, BidCancelled};
    use openmark::errors as Errors;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    component!(path: HasherComponent, storage: hasher, event: HasherEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl HasherImpl = HasherComponent::HasherImpl<ContractState>;

    pub type Signature = (felt252, felt252);

    pub const MAX_COMMISSION: u32 = 500; // per mille (fixed 50%)
    pub const PERMYRIAD: u32 = 1000;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        HasherEvent: HasherComponent::Event,
        OrderFilled: OrderFilled,
        OrderCancelled: OrderCancelled,
        BidsFilled: BidsFilled,
        BidCancelled: BidCancelled,
    }


    #[storage]
    struct Storage {
        eth_token: IERC20Dispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        hasher: HasherComponent::Storage, // hash provider
        commission: u32, // OpenMark's commission (per mille)
        maxBids: u32, // Maximum number of bids allowed in fillBids
        usedSignatures: LegacyMap<Signature, bool>, // store used order signatures
        partialBidSignatures: LegacyMap<Signature, u128>, // store partial bid signatures
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, eth_address: ContractAddress) {
        self.eth_token.write(IERC20Dispatcher { contract_address: eth_address });
        self.ownable.initializer(owner);
        self.commission.write(0);
        self.maxBids.write(10);
    }


    #[abi(embed_v0)]
    impl OpenMarkImpl of IOpenMark<ContractState> {
        fn buy(
            ref self: ContractState, seller: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            // 1. verify order
            validate_order(@self, order, seller, get_caller_address(), OrderType::Buy);

            // 2. verify signature
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );
            assert(
                self.hasher.verify_order(order, seller.into(), signature), Errors::INVALID_SIGNATURE
            );

            // 3. make trade
            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };
            nft_dispatcher.transfer_from(seller, get_caller_address(), order.tokenId.into());

            let price: u256 = order.price.into();
            let commission = calculate_commission(price, self.commission.read());
            let payout = price - commission;
            self.eth_token.read().transfer(seller, payout);
            self.eth_token.read().transfer(get_contract_address(), commission);

            // 4. change storage
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);

            // 5. emit events
            self.emit(OrderFilled { seller, buyer: get_caller_address(), order });
        }

        fn accept_offer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            // 1. verify order
            validate_order(@self, order, get_caller_address(), buyer, OrderType::Offer);

            // 2. verify signature
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );
            assert(
                self.hasher.verify_order(order, buyer.into(), signature), Errors::INVALID_SIGNATURE
            );

            // 3. make trade
            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };
            nft_dispatcher.transfer_from(get_caller_address(), buyer, order.tokenId.into());

            let price: u256 = order.price.into();
            let commission = calculate_commission(price, self.commission.read());
            let payout = price - commission;
            self.eth_token.read().transfer_from(buyer, get_caller_address(), payout);
            self.eth_token.read().transfer_from(buyer, get_contract_address(), commission);

            // 4. change storage
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);
            // 5. emit events
            self.emit(OrderFilled { seller: get_caller_address(), buyer, order });
        }

        fn fill_bids(
            ref self: ContractState,
            bids: Span<SignedBid>,
            nftContract: ContractAddress,
            tokenIds: Span<u128>,
            askPrice: u128
        ) {
            let hasher = @(self).hasher;

            // 1. Verify signatures
            {
                let mut i = 0;
                while (i < bids.len()) {
                    let signature = (*bids.at(i)).signature;
                    assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
                    assert(
                        !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                        Errors::SIGNATURE_USED
                    );

                    assert(
                        hasher
                            .verify_bid((*bids.at(i)).bid, (*bids.at(i)).bidder.into(), signature),
                        Errors::INVALID_SIGNATURE
                    );
                    i += 1;
                };
            }

            // 2. Validate Bids
            let total_bid_amount = validate_bids(
                @self, bids, get_caller_address(), nftContract, tokenIds, askPrice
            );

            // 3. Efficient loop for fee calculation and payout to wholesale bidders
            let nft_dispatcher = IERC721Dispatcher { contract_address: nftContract };
            let mut trade_token_ids = tokenIds;

            {
                let commission = self.commission.read();

                let mut i = 0;
                while (i < bids.len() - 1) {
                    let signed_bid = (*bids.at(i));
                    let signature = (*signed_bid.signature.at(0), *signed_bid.signature.at(1));
                    let bid = signed_bid.bid;

                    let mut amount = bid.amount;
                    {
                        let partial_signature_amount = self.partialBidSignatures.read(signature);
                        if partial_signature_amount > 0 {
                            amount = partial_signature_amount;
                        }
                    }

                    {
                        let price: u256 = (bid.unitPrice * amount).into();
                        let commission = calculate_commission(price, commission);
                        let payout = price - commission;

                        self
                            .eth_token
                            .read()
                            .transfer_from(signed_bid.bidder, get_caller_address(), payout);

                        self
                            .eth_token
                            .read()
                            .transfer_from(signed_bid.bidder, get_contract_address(), commission);

                        let mut token_index: u128 = 0;
                        while (token_index < amount) {
                            let token_id: u256 = (*trade_token_ids.pop_front().unwrap()).into();
                            nft_dispatcher
                                .transfer_from(get_caller_address(), *bids.at(i).bidder, token_id);
                            token_index += 1;
                        };
                    }

                    self.usedSignatures.write(signature, true);
                    self.partialBidSignatures.write(signature, 0);

                    i += 1;
                }
            }
            // 4. Separate logic for last bidder to handle remaining NFTs
            {
                let signed_bid = *bids.at(bids.len() - 1);
                let signature = (*signed_bid.signature.at(0), *signed_bid.signature.at(1));

                let remaining_amount = total_bid_amount - tokenIds.len().into();
                let mut amount = signed_bid.bid.amount;
                {
                    let partial_signature_amount = self.partialBidSignatures.read(signature);
                    if partial_signature_amount > 0 {
                        amount = partial_signature_amount;
                    }
                    amount -= remaining_amount;
                }

                let price = (amount * signed_bid.bid.unitPrice).into();

                let commission = calculate_commission(price, self.commission.read());
                let payout = price - commission;

                self
                    .eth_token
                    .read()
                    .transfer_from(signed_bid.bidder, get_caller_address(), payout);

                self
                    .eth_token
                    .read()
                    .transfer_from(signed_bid.bidder, get_contract_address(), commission);

                let mut token_index: u128 = 0;
                while (token_index < amount) {
                    let token_id: u256 = (*trade_token_ids.pop_front().unwrap()).into();
                    nft_dispatcher.transfer_from(get_caller_address(), signed_bid.bidder, token_id);
                    token_index += 1;
                };

                self.partialBidSignatures.write(signature, remaining_amount);
                if (remaining_amount == 0) {
                    self.usedSignatures.write(signature, true);
                }
            }

            // 5. emit events
            let mut raw_bids = ArrayTrait::new();
            {
                let mut i = 0;
                while (i < bids.len()) {
                    raw_bids.append(*bids.at(i).bid);
                    i += 1;
                }
            }
            self
                .emit(
                    BidsFilled {
                        seller: get_caller_address(), bids: raw_bids.span(), nftContract, tokenIds,
                    }
                );
        }

        fn cancel_order(ref self: ContractState, order: Order, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );

            assert(
                self.hasher.verify_order(order, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);

            self.emit(OrderCancelled { who: get_caller_address(), order, });
        }

        fn cancel_bid(ref self: ContractState, bid: Bid, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );

            assert(
                self.hasher.verify_bid(bid, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);
            self.emit(BidCancelled { who: get_caller_address(), bid, });
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

        fn is_used_signature(self: @ContractState, signature: Span<felt252>) -> bool {
            self.usedSignatures.read((*signature.at(0), *signature.at(1)))
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkManagerImpl of IOpenMarkManager<ContractState> {
        fn set_commission(ref self: ContractState, new_commission: u32) {
            self.ownable.assert_only_owner();
            assert(new_commission < MAX_COMMISSION, Errors::COMMISSION_TOO_HIGH);
            self.commission.write(new_commission);
        }
    }

    #[abi(embed_v0)]
    fn calculate_commission(price: u256, commission: u32) -> u256 {
        price * commission.into() / PERMYRIAD.into()
    }

    #[abi(embed_v0)]
    pub fn validate_order(
        self: @ContractState,
        order: Order,
        seller: ContractAddress,
        buyer: ContractAddress,
        order_type: OrderType
    ) {
        assert(order.expiry > get_block_timestamp().into(), Errors::SIGNATURE_EXPIRED);
        assert(order.option == order_type, Errors::INVALID_ORDER_TYPE);

        let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };

        assert(!seller.is_zero(), Errors::ZERO_ADDRESS);
        assert(!buyer.is_zero(), Errors::ZERO_ADDRESS);
        assert(nft_dispatcher.owner_of(order.tokenId.into()) == seller, Errors::SELLER_NOT_OWNER);

        let price: u256 = order.price.into();
        assert(price > 0, Errors::PRICE_IS_ZERO);
    }

    #[abi(embed_v0)]
    pub fn validate_bids(
        self: @ContractState,
        bids: Span<SignedBid>,
        seller: ContractAddress,
        nftContract: ContractAddress,
        tokenIds: Span<u128>,
        askPrice: u128
    ) -> u128 {
        assert(bids.len() > 0, Errors::NO_BIDS);
        assert(bids.len() < self.maxBids.read(), Errors::TOO_MANY_BIDS);
        assert(!seller.is_zero(), Errors::ZERO_ADDRESS);

        {
            let mut i = 0;
            while (i < bids.len()) {
                let signed_bid = *bids.at(i);
                assert(!signed_bid.bidder.is_zero(), Errors::ZERO_ADDRESS);
                let bid = signed_bid.bid;

                assert(bid.amount > 0, Errors::ZERO_BIDS_AMOUNT);
                assert(bid.unitPrice > 0, Errors::PRICE_IS_ZERO);
                assert(bid.unitPrice >= askPrice, Errors::ASKING_PRICE_TOO_HIGH);
                assert(bid.expiry > get_block_timestamp().into(), Errors::SIGNATURE_EXPIRED);
                assert(bid.nftContract == nftContract, Errors::NFT_MISMATCH);
                i += 1;
            };
        }

        // 3. Verify token owner
        let nft_dispatcher = IERC721Dispatcher { contract_address: nftContract };
        {
            let mut i = 0;
            while (i < tokenIds.len()) {
                assert(
                    nft_dispatcher.owner_of((*tokenIds.at(i)).into()) == seller,
                    Errors::SELLER_NOT_OWNER
                );
                i += 1;
            }
        }

        let mut min_bid_amount = 0;
        let mut total_bid_amount = 0;
        {
            let mut i = 0;
            while (i < bids.len()) {
                let bid = (*bids.at(i)).bid;
                let signature = (*(*bids.at(i)).signature.at(0), *(*bids.at(i)).signature.at(1));

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
        assert(tokenIds.len().into() > min_bid_amount, Errors::NOT_ENOUGH_BID_NFT);

        total_bid_amount
    }
}
