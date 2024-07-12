use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Order, Bid, SignedBid};

#[starknet::interface]
pub trait IOpenMark<TState> {
    fn buy(ref self: TState, seller: ContractAddress, order: Order, signature: Span<felt252>);

    fn accept_offer(
        ref self: TState, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn fill_bids(
        ref self: TState,
        bids: Span<SignedBid>,
        nftContract: ContractAddress,
        tokenIds: Span<u128>,
        askingPrice: u128
    );

    fn cancel_order(ref self: TState, order: Order, signature: Span<felt252>);

    fn cancel_bid(ref self: TState, bid: Bid, signature: Span<felt252>);
}

#[starknet::interface]
pub trait IOpenMarkProvider<TState> {
    fn get_chain_id(self: @TState) -> felt252;
    fn get_commission(self: @TState) -> u32;
    fn is_used_signature(self: @TState, signature: Span<felt252>) -> bool;
}

#[starknet::interface]
pub trait IOpenMarkManager<TState> {
    fn set_commission(ref self: TState, new_commission: u32);
}
