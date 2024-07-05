#[starknet::contract]
pub mod OpenMark {
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
    use openmark::events::{OrderFilled, OrderCancelled, BidFilled, BidCancelled};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    component!(path: HasherComponent, storage: hasher, event: HasherEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl HasherImpl = HasherComponent::HasherImpl<ContractState>;

    pub type Signature = (felt252, felt252);

    pub const MAX_COMMISSION: u32 = 500; // per mille (fixed 50%)
    pub const PERMYRIAD: u32 = 1000;

    mod Errors {
        pub const SIGNATURE_USED: felt252 = 'OPENMARK: sig used';
        pub const INVALID_SIGNATURE: felt252 = 'OPENMARK: invalid sig';
        pub const INVALID_SIGNATURE_LEN: felt252 = 'OPENMARK: invalid sig len';
        pub const INVALID_SELLER: felt252 = 'OPENMARK: invalid seller';
        pub const ZERO_ADDRESS: felt252 = 'OPENMARK: caller is zero';
        pub const PRICE_IS_ZERO: felt252 = 'OPENMARK: price is zero';
        pub const SIGNATURE_EXPIRED: felt252 = 'OPENMARK: sig expired';
        pub const INVALID_ORDER_TYPE: felt252 = 'OPENMARK: invalid order type';

        pub const NOT_OWNER: felt252 = 'OPENMARK: not the owner';
        pub const INVALID_BUYER: felt252 = 'OPENMARK: invalid buyer';
        pub const INSUFFICIENT_NFTS: felt252 = 'OPENMARK: insufficient nfts';
        pub const TOO_MANY_BIDS: felt252 = 'OPENMARK: too many bids';
        pub const ZERO_BIDS: felt252 = 'OPENMARK: zero bids';
        pub const ASKING_PRICE_TOO_HIGH: felt252 = 'OPENMARK: asking too high';

        pub const INVALID_BID_NFT: felt252 = 'OPENMARK: invalid nft';
        pub const TOO_MANY_BID_NFT: felt252 = 'OPENMARK: too many nfts';
        pub const NOT_ENOUGH_BID_NFT: felt252 = 'OPENMARK: not enough nfts';

        pub const COMMISSION_TOO_HIGH: felt252 = 'OPENMARK: commission too high';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        HasherEvent: HasherComponent::Event,
        OrderFilled: OrderFilled,
        OrderCancelled: OrderCancelled,
        BidFilled: BidFilled,
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
        usedSignatures: LegacyMap<Signature, bool>, // store used signature
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, eth_address: ContractAddress) {
        self.eth_token.write(IERC20Dispatcher { contract_address: eth_address });
        self.ownable.initializer(owner);
        self.commission.write(0);
    }


    #[abi(embed_v0)]
    impl OpenMarkImpl of IOpenMark<ContractState> {
        fn buy(
            ref self: ContractState, seller: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            // 1. verify inputs
            assert(order.expiry > get_block_timestamp().into(), Errors::SIGNATURE_EXPIRED);
            assert(order.option == OrderType::Buy, Errors::INVALID_ORDER_TYPE);

            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };

            assert(nft_dispatcher.owner_of(order.tokenId.into()) == seller, Errors::INVALID_SELLER);

            let price: u256 = order.price.into();
            assert(price > 0, Errors::PRICE_IS_ZERO);

            // 2. verify signature
            assert(!seller.is_zero(), Errors::ZERO_ADDRESS);

            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );
            assert(
                self.hasher.verifyOrder(order, seller.into(), signature), Errors::INVALID_SIGNATURE
            );

            // 3. make trade
            nft_dispatcher.transfer_from(seller, get_caller_address(), order.tokenId.into());

            let commission = calculate_commission(@self, price);
            let payout = price - commission;
            self.eth_token.read().transfer(seller, payout);
            self.eth_token.read().transfer(get_contract_address(), commission);

            // 4. change storage
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);

            // 5. emit events
            self.emit(OrderFilled { seller, buyer: get_caller_address(), order });
        }

        fn acceptOffer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            // 1. verify inputs
            assert(order.expiry > get_block_timestamp().into(), Errors::SIGNATURE_EXPIRED);
            assert(order.option == OrderType::Offer, Errors::INVALID_ORDER_TYPE);

            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };

            assert(
                nft_dispatcher.owner_of(order.tokenId.into()) == get_caller_address(),
                Errors::NOT_OWNER
            );

            let price: u256 = order.price.into();
            assert(price > 0, Errors::PRICE_IS_ZERO);

            // 2. verify signature
            assert(!buyer.is_zero(), Errors::ZERO_ADDRESS);

            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );
            assert(
                self.hasher.verifyOrder(order, buyer.into(), signature), Errors::INVALID_SIGNATURE
            );

            // 3. make trade
            nft_dispatcher.transfer_from(get_caller_address(), buyer, order.tokenId.into());

            let commission = calculate_commission(@self, price);
            let payout = price - commission;
            self.eth_token.read().transfer_from(buyer, get_caller_address(), payout);
            self.eth_token.read().transfer_from(buyer, get_contract_address(), commission);

            // 4. change storage
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);
        // 5. emit events

        }

        fn confirmBid(
            ref self: ContractState,
            bids: Span<SignedBid>,
            nftContract: ContractAddress,
            tokenIds: Span<felt252>,
            askPrice: u128
        ) {
            let hasher = @(self).hasher;

            // 1. Verify inputs
            let mut total_bid_amount = 0;
            assert(bids.len() < 10, Errors::TOO_MANY_BIDS);
            {
                let mut i = 0;
                while (i < bids.len()) {
                    assert((*bids.at(i)).bid.amount > 0, Errors::ZERO_BIDS);
                    assert((*bids.at(i)).bid.unitPrice > 0, Errors::PRICE_IS_ZERO);
                    assert((*bids.at(i)).bid.unitPrice >= askPrice, Errors::ASKING_PRICE_TOO_HIGH);
                    assert(
                        (*bids.at(i)).bid.expiry > get_block_timestamp().into(),
                        Errors::SIGNATURE_EXPIRED
                    );
                    assert((*bids.at(i)).bid.nftContract == nftContract, Errors::INVALID_BID_NFT);

                    i += 1;
                };
            }

            let mut min_bid_amount = 0;
            {
                let mut i = 0;

                while (i < bids.len()) {
                    total_bid_amount += (*bids.at(i)).bid.amount;
                    if i < bids.len() - 1 {
                        min_bid_amount += (*bids.at(i)).bid.amount;
                    }
                    i += 1;
                };
            }

            assert(tokenIds.len().into() <= total_bid_amount, Errors::TOO_MANY_BID_NFT);
            assert(tokenIds.len().into() > min_bid_amount, Errors::NOT_ENOUGH_BID_NFT);

            let nft_dispatcher = IERC721Dispatcher { contract_address: nftContract };
            // 2. Verify token owner
            {
                let mut i = 0;
                while (i < tokenIds.len()) {
                    assert(
                        nft_dispatcher.owner_of((*tokenIds.at(i)).into()) == get_caller_address(),
                        Errors::NOT_OWNER
                    );
                    i += 1;
                }
            }

            // 3. Verify signatures
            {
                let mut i = 0;
                while (i < bids.len()) {
                    let signature = (*bids.at(i)).signature;
                    assert(
                        !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                        Errors::SIGNATURE_USED
                    );

                    assert(
                        hasher.verifyBid((*bids.at(i)).bid, (*bids.at(i)).bidder.into(), signature),
                        Errors::INVALID_SIGNATURE
                    );
                    i += 1;
                };
            }
            // 3. Efficient loop for fee calculation and payout to wholesale bidders
            {
                let mut i = 0;
                while (i < bids.len() - 1) {
                    let price: u256 = ((*bids.at(i)).bid.unitPrice * (*bids.at(i)).bid.amount)
                        .into();
                    // let commission = calculate_commission(@self, price);
                    let commission = 0;
                    let payout = price - commission;

                    self
                        .eth_token
                        .read()
                        .transfer_from((*bids.at(i)).bidder, get_caller_address(), payout);

                    self
                        .eth_token
                        .read()
                        .transfer_from((*bids.at(i)).bidder, get_contract_address(), commission);

                    let signature = *bids.at(i).signature;
                    self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);

                    i += 1;
                }
            }
            // 4. Separate logic for last bidder to handle remaining NFTs
            {
                let last_bid = *bids.at(bids.len() - 1);

                let remaining_amount = last_bid.bid.amount
                    - (total_bid_amount - tokenIds.len().into());
                let price = (remaining_amount * last_bid.bid.unitPrice).into();

                let commission = calculate_commission(@self, price);
                let payout = price - commission;

                self.eth_token.read().transfer_from(last_bid.bidder, get_caller_address(), payout);

                self
                    .eth_token
                    .read()
                    .transfer_from(last_bid.bidder, get_contract_address(), commission);

                self
                    .usedSignatures
                    .write((*last_bid.signature.at(0), *last_bid.signature.at(1)), true);
            }
            // 5. Iterate through tokenIds to transfer NFTs efficiently
            {
                let mut i = 0;
                let mut token_index = 0;
                while (i < bids.len()) {
                    let mut j = 0;
                    while (token_index < tokenIds.len().into() && j < (*bids.at(i)).bid.amount) {
                        nft_dispatcher
                            .transfer_from(
                                get_caller_address(),
                                *bids.at(i).bidder,
                                (*tokenIds.at(token_index)).into()
                            );
                        j += 1;
                        token_index += 1;
                    };
                    i += 1;
                }
            }
        // 6. Emit Event
        }

        fn cancelOrder(ref self: ContractState, order: Order, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );

            assert(
                self.hasher.verifyOrder(order, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);
        }

        fn cancelBid(ref self: ContractState, bid: Bid, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(
                !self.usedSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );

            assert(
                self.hasher.verifyBid(bid, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedSignatures.write((*signature.at(0), *signature.at(1)), true);
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkProviderImpl of IOpenMarkProvider<ContractState> {
        fn get_chain_id(self: @ContractState) -> felt252 {
            get_tx_info().unbox().chain_id
        }

        fn get_commission(self: @ContractState) -> u32 {
            0
        }

        fn is_used_signature(self: @ContractState, signature: Span<felt252>) -> bool {
            false
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
    fn calculate_commission(self: @ContractState, price: u256) -> u256 {
        // need safe math
        self.commission.read().into() * price / PERMYRIAD.into()
    }
}
