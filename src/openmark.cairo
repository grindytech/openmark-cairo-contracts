#[starknet::contract]
mod OpenMark {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{
        IERC721, IERC721Dispatcher, IERC721DispatcherTrait
    };
    use openzeppelin::account::utils::{is_valid_stark_signature};
    use starknet::{
        get_caller_address, get_contract_address, get_tx_info, ContractAddress, get_block_timestamp,
    };
    use core::pedersen::PedersenTrait;
    use core::num::traits::Zero;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::ecdsa::check_ecdsa_signature;
    use openmark::primitives::{
        Order, OrderType, ORDER_STRUCT_TYPE_HASH, StarknetDomain, IStructHash, Bid
    };
    use openmark::interface::{IOpenMark, IOffchainMessageHash};
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    pub type Signature = (felt252, felt252);

    mod Errors {
        pub const SIGNATURE_USED: felt252 = 'OPENMARK: sig used';
        pub const INVALID_SIGNATURE: felt252 = 'OPENMARK: invalid sig';
        pub const INVALID_SIGNATURE_LEN: felt252 = 'OPENMARK: invalid sig len';
        pub const INVALID_SELLER: felt252 = 'OPENMARK: invalid seller';
        pub const ZERO_ADDRESS: felt252 = 'OPENMARK: caller is zero';
        pub const INVALID_PRICE: felt252 = 'OPENMARK: invalid price';
        pub const EXPIRED_OR_SOLD: felt252 = 'OPENMARK: expired or sold out';
        pub const INVALID_ORDER_TYPE: felt252 = 'OPENMARK: invalid order type';

        pub const NOT_OWNER: felt252 = 'OPENMARK: not the owner';
        pub const INVALID_BUYER: felt252 = 'OPENMARK: invalid buyer';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }


    #[storage]
    struct Storage {
        eth_token: IERC20Dispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        usedOrderSignatures: LegacyMap<Signature, bool>, // store used signature
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, eth_address: ContractAddress) {
        self.eth_token.write(IERC20Dispatcher { contract_address: eth_address });

        self.ownable.initializer(owner);
    }


    #[abi(embed_v0)]
    impl OpenMarkImpl of IOpenMark<ContractState> {
        // fn acceptOffer(self: @ContractState) {}

        // fn cancelOrder(self: @ContractState) {}

        fn buy(
            ref self: ContractState, seller: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            // 1. verify inputs
            assert(order.expiry > get_block_timestamp().into(), Errors::EXPIRED_OR_SOLD);
            assert(order.option == OrderType::Buy, Errors::INVALID_ORDER_TYPE);

            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };

            assert(nft_dispatcher.owner_of(order.tokenId.into()) == seller, Errors::INVALID_SELLER);

            let price: u256 = order.price.into();
            assert(price > 0, Errors::INVALID_PRICE);

            // 2. verify signature
            assert(!seller.is_zero(), Errors::ZERO_ADDRESS);

            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(
                !self.usedOrderSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );
            assert(self.verifyOrder(order, seller.into(), signature), Errors::INVALID_SIGNATURE);

            // 3. make trade
            nft_dispatcher.transfer_from(seller, get_caller_address(), order.tokenId.into());

            self.eth_token.read().transfer(seller, price);

            // 4. change storage
            self.usedOrderSignatures.write((*signature.at(0), *signature.at(1)), true);
        }

        fn acceptOffer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>
        ) {
            // 1. verify inputs
            assert(order.expiry > get_block_timestamp().into(), Errors::EXPIRED_OR_SOLD);
            assert(order.option == OrderType::Offer, Errors::INVALID_ORDER_TYPE);

            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };

            assert(
                nft_dispatcher.owner_of(order.tokenId.into()) == get_caller_address(),
                Errors::NOT_OWNER
            );

            let price: u256 = order.price.into();
            assert(price > 0, Errors::INVALID_PRICE);

            // 2. verify signature
            assert(!buyer.is_zero(), Errors::ZERO_ADDRESS);

            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(
                !self.usedOrderSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );
            assert(self.verifyOrder(order, buyer.into(), signature), Errors::INVALID_SIGNATURE);

            // 3. make trade
            nft_dispatcher.transfer_from(get_caller_address(), buyer, order.tokenId.into());
            self.eth_token.read().transfer_from(buyer, get_caller_address(), price);

            // 4. change storage
            self.usedOrderSignatures.write((*signature.at(0), *signature.at(1)), true);
        }

        fn cancelOrder(ref self: ContractState, order: Order, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(
                !self.usedOrderSignatures.read((*signature.at(0), *signature.at(1))),
                Errors::SIGNATURE_USED
            );

            assert(
                self.verifyOrder(order, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE
            );
            self.usedOrderSignatures.write((*signature.at(0), *signature.at(1)), true);
        }

        fn verifyOrder(
            self: @ContractState, order: Order, signer: felt252, signature: Span<felt252>
        ) -> bool {
            let hash = self.get_order_hash(order, signer);

            is_valid_stark_signature(hash, signer, signature)
        }

        fn verifyBid(
            self: @ContractState, bid: Bid, signer: felt252, signature: Span<felt252>
        ) -> bool {
            let hash = self.get_bid_hash(bid, signer);

            is_valid_stark_signature(hash, signer, signature)
        }
    }

    #[abi(embed_v0)]
    impl OffchainMessageHashImpl of IOffchainMessageHash<ContractState> {
        fn get_order_hash(self: @ContractState, order: Order, signer: felt252) -> felt252 {
            let domain = StarknetDomain {
                name: 'OpenMark', version: 1, chain_id: get_tx_info().unbox().chain_id
            };
            let mut state = PedersenTrait::new(0);
            state = state.update_with('StarkNet Message');
            state = state.update_with(domain.hash_struct());
            state = state.update_with(signer);
            state = state.update_with(order.hash_struct());
            // Hashing with the amount of elements being hashed 
            state = state.update_with(4);
            state.finalize()
        }

        fn get_bid_hash(self: @ContractState, bid: Bid, signer: felt252) -> felt252 {
            let domain = StarknetDomain {
                name: 'OpenMark', version: 1, chain_id: get_tx_info().unbox().chain_id
            };
            let mut state = PedersenTrait::new(0);
            state = state.update_with('StarkNet Message');
            state = state.update_with(domain.hash_struct());
            state = state.update_with(signer);
            state = state.update_with(bid.hash_struct());
            // Hashing with the amount of elements being hashed 
            state = state.update_with(4);
            state.finalize()
        }
    }
}
