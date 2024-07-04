// use starknet::ContractAddress;
// use openmark::interface::{IOffchainMessageHash};

// #[starknet::interface]
// trait IOwnableCounter<TContractState> {
//     fn get_counter(self: @TContractState) -> u32;
//     fn increment(ref self: TContractState);
//     fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
// }

// #[starknet::component]
// mod HasherComponent {
//     use starknet::ContractAddress;

//     #[storage]
//     struct Storage {
//     }


//      #[embeddable_as(OffchainMessageHashImpl)]
//     impl OffchainMessageHashImpl of IOffchainMessageHash<ContractState> {
//         fn get_order_hash(self: @ContractState, order: Order, signer: felt252) -> felt252 {
//             let domain = StarknetDomain {
//                 name: 'OpenMark', version: 1, chain_id: get_tx_info().unbox().chain_id
//             };
//             let mut state = PedersenTrait::new(0);
//             state = state.update_with('StarkNet Message');
//             state = state.update_with(domain.hash_struct());
//             state = state.update_with(signer);
//             state = state.update_with(order.hash_struct());
//             // Hashing with the amount of elements being hashed 
//             state = state.update_with(4);
//             state.finalize()
//         }

//         fn get_bid_hash(self: @ContractState, bid: Bid, signer: felt252) -> felt252 {
//             let domain = StarknetDomain {
//                 name: 'OpenMark', version: 1, chain_id: get_tx_info().unbox().chain_id
//             };
//             let mut state = PedersenTrait::new(0);
//             state = state.update_with('StarkNet Message');
//             state = state.update_with(domain.hash_struct());
//             state = state.update_with(signer);
//             state = state.update_with(bid.hash_struct());
//             // Hashing with the amount of elements being hashed 
//             state = state.update_with(4);
//             state.finalize()
//         }
//     }
// }