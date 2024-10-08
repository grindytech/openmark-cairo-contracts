#[starknet::contract]
pub mod HasherMock {
    use openmark::hasher::interface::{IOffchainMessageHash};
    use openmark::hasher::interface::{IAccountDispatcher, IAccountDispatcherTrait};
    use openmark::primitives::types::{Order, Bid, StarknetDomain, IStructHash};

    use starknet::{VALIDATED, get_tx_info};
    use openzeppelin::account::utils::{is_valid_stark_signature};
    use openzeppelin::introspection::src5::SRC5Component;

    // Hash
    use core::poseidon::PoseidonTrait;
    use core::poseidon::poseidon_hash_span;
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // SCR5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[abi(embed_v0)]
    impl Hasher of IOffchainMessageHash<ContractState> {
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

        fn verify_order(
            self: @ContractState, order: Order, signer: felt252, signature: Span<felt252>
        ) -> bool {
            let hash = self.get_order_hash(order, signer);
            self.verify_signature(hash, signer, signature)
        }

        fn verify_bid(
            self: @ContractState, bid: Bid, signer: felt252, signature: Span<felt252>
        ) -> bool {
            let hash = self.get_bid_hash(bid, signer);
            self.verify_signature(hash, signer, signature)
        }

        fn hash_array(self: @ContractState, value: Span<felt252>) -> felt252 {
            let hash = PoseidonTrait::new().update(poseidon_hash_span(value)).finalize();
            hash
        }

        fn verify_signature(
            self: @ContractState, hash: felt252, signer: felt252, signature: Span<felt252>
        ) -> bool {
            // check public key
            if (is_valid_stark_signature(hash, signer, signature)) {
                return true;
            } else {
                // check contract address
                let account_contract = IAccountDispatcher {
                    contract_address: signer.try_into().unwrap()
                };
                if account_contract
                    .is_valid_signature(
                        hash, array![*signature.at(0), *signature.at(1)]
                    ) == VALIDATED {
                    return true;
                }
            }
            return false;
        }
    }
}
