#[starknet::contract]
pub(crate) mod HasherMock {
    use starknet::ContractAddress;
    use openmark::hasher::interface::{IOffchainMessageHash};
    use openmark::primitives::types::{Order, Bid, StarknetDomain, IStructHash};
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::ecdsa::check_ecdsa_signature;
    use starknet::{get_caller_address, get_contract_address, get_tx_info, get_block_timestamp,};
    use openzeppelin::account::utils::{is_valid_stark_signature};
    use openzeppelin::introspection::src5::SRC5Component;

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
                println!("HERE1");

                // check account contract
                if let Option::Some(account) = signer.try_into() {
                    let mut args = array![];
                    args.append_serde(hash);
                    args.append_serde(signature);
                    println!("HERE2");
                    match call_contract_syscall(account, IS_VALID_SIGNATURE_SELECTOR, args.span()) {
                        Result::Ok(ret) => {
                            if ret.len() > 0 && *ret.at(0) == VALIDATED {
                                return true;
                            }
                        },
                        Result::Err(_) => { return false; }
                    }
                }
            }
            return false;
        }
    }
}
