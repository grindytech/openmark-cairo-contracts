use openmark::primitives::types::{Order};
use starknet::account::Call;

#[starknet::interface]
pub trait IOffchainMessageHash<T> {
    fn get_order_hash(self: @T, order: Order, signer: felt252) -> felt252;

    fn verify_order(self: @T, order: Order, signer: felt252, signature: Span<felt252>) -> bool;
    fn verify_signature(self: @T, hash: felt252, signer: felt252, signature: Span<felt252>) -> bool;
    fn hash_array(self: @T, value: Span<felt252>) -> felt252;
}