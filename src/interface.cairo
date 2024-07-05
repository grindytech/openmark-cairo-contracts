use starknet::ContractAddress;
use openmark::primitives::{Order, Bid, SignedBid};

#[starknet::interface]
pub trait IOpenMark<TState> {
    fn buy(ref self: TState, seller: ContractAddress, order: Order, signature: Span<felt252>);

    fn acceptOffer(
        ref self: TState, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );


    fn confirmBid(
        ref self: TState,
        bids: Span<SignedBid>,
        nftContract: ContractAddress,
        tokenIds: Span<felt252>,
        askPrice: u128
    );

    fn cancelOrder(ref self: TState, order: Order, signature: Span<felt252>);

    fn cancelBid(ref self: TState, bid: Bid, signature: Span<felt252>);
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


#[starknet::interface]
pub trait IOffchainMessageHash<T> {
    fn get_order_hash(self: @T, order: Order, signer: felt252) -> felt252;
    fn get_bid_hash(self: @T, bid: Bid, signer: felt252) -> felt252;

    fn verifyOrder(self: @T, order: Order, signer: felt252, signature: Span<felt252>) -> bool;
    fn verifyBid(self: @T, bid: Bid, signer: felt252, signature: Span<felt252>) -> bool;
}

#[starknet::interface]
pub trait IOM721Token<T> {
    fn safe_mint(ref self: T, to: ContractAddress, quantity: u256);
}
