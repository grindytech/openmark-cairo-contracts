#[starknet::contract]
pub mod HasherMock {
    use starknet::ContractAddress;
    use openmark::interface::{IOffchainMessageHash};
    use openmark::primitives::{Order, Bid, StarknetDomain, IStructHash};
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::ecdsa::check_ecdsa_signature;
    use starknet::{get_caller_address, get_contract_address, get_tx_info, get_block_timestamp,};
    use openzeppelin::account::utils::{is_valid_stark_signature};

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {}

    #[abi(embed_v0)]
    impl Hasher of IOffchainMessageHash<ContractState> {
        fn get_order_hash(
            self: @ContractState, order: Order, signer: felt252
        ) -> felt252 {
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

        fn get_bid_hash(
            self: @ContractState, bid: Bid, signer: felt252
        ) -> felt252 {
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

        fn verify_order(
            self: @ContractState,
            order: Order,
            signer: felt252,
            signature: Span<felt252>
        ) -> bool {
            let hash = self.get_order_hash(order, signer);
            is_valid_stark_signature(hash, signer, signature)
        }

        fn verify_bid(
            self: @ContractState,
            bid: Bid,
            signer: felt252,
            signature: Span<felt252>
        ) -> bool {
            let hash = self.get_bid_hash(bid, signer);
            is_valid_stark_signature(hash, signer, signature)
        }
    }
}
