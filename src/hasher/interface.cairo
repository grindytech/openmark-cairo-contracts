use openmark::primitives::types::{Order, Bid, SignedBid};

#[starknet::interface]
pub trait IOffchainMessageHash<T> {
    fn get_order_hash(self: @T, order: Order, signer: felt252) -> felt252;
    fn get_bid_hash(self: @T, bid: Bid, signer: felt252) -> felt252;

    fn verify_order(self: @T, order: Order, signer: felt252, signature: Span<felt252>) -> bool;
    fn verify_bid(self: @T, bid: Bid, signer: felt252, signature: Span<felt252>) -> bool;
}