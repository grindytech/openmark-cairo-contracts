// SPDX-License-Identifier: MIT
// OpenMark Contracts for Cairo

/// # Hasher Component
///
/// This component provides implementations for cryptographic hashing functions,
/// specifically designed for use with the EIP-712 standard. EIP-712 is used to
/// create typed structured data hashes, enabling secure and user-friendly
/// off-chain signature verification. This is crucial for ensuring data integrity
/// and authenticity in decentralized applications (dApps) on StarkNet.
#[starknet::component]
pub mod HasherComponent {
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use starknet::{ VALIDATED,  get_tx_info};

    use openzeppelin::utils::serde::SerializedAppend;
    use openmark::hasher::interface::{IOffchainMessageHash};
    use openmark::primitives::types::{Order, Bid, StarknetDomain, IStructHash};

    use openzeppelin::account::utils::{is_valid_stark_signature};
    use openzeppelin::utils::{try_selector_with_fallback};
    use openzeppelin::utils::selectors;
    use openzeppelin::utils::UnwrapAndCast;


    // Hash
    use core::poseidon::PoseidonTrait;
    use core::poseidon::poseidon_hash_span;
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(HasherImpl)]
    impl Hasher<
        TContractState, +HasComponent<TContractState>
    > of IOffchainMessageHash<ComponentState<TContractState>> {
        fn get_order_hash(
            self: @ComponentState<TContractState>, order: Order, signer: felt252
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
            self: @ComponentState<TContractState>, bid: Bid, signer: felt252
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
            self: @ComponentState<TContractState>,
            order: Order,
            signer: felt252,
            signature: Span<felt252>
        ) -> bool {
            let hash = self.get_order_hash(order, signer);
            self.verify_signature(hash, signer, signature)
        }

        fn verify_bid(
            self: @ComponentState<TContractState>,
            bid: Bid,
            signer: felt252,
            signature: Span<felt252>
        ) -> bool {
            let hash = self.get_bid_hash(bid, signer);
            self.verify_signature(hash, signer, signature)
        }

        fn verify_signature(
            self: @ComponentState<TContractState>,
            hash: felt252,
            signer: felt252,
            signature: Span<felt252>
        ) -> bool {
            // check public key
            if (is_valid_stark_signature(hash, signer, signature)) {
                return true;
            } else {
                if let Option::Some(account) = signer.try_into() {
                    let mut args = array![];
                    args.append_serde(hash);
                    args.append_serde(signature);

                    let result = try_selector_with_fallback(
                        account,
                        selectors::is_valid_signature,
                        selectors::isValidSignature,
                        args.span()
                    )
                        .unwrap_and_cast();

                    if result == VALIDATED {
                        return true;
                    }
                }
            }
            return false;
        }

        fn hash_array(self: @ComponentState<TContractState>, value: Span<felt252>) -> felt252 {
            let hash = PoseidonTrait::new().update(poseidon_hash_span(value)).finalize();
            hash
        }
    }
}
