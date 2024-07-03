use starknet::ContractAddress;
use openmark::primitives::Order;

#[starknet::interface]
pub trait IOpenMark<TState> {
    // fn acceptOffer(ref self:  TState);
    // fn cancelOrder(ref self:  TState);

    fn buy(ref self: TState, seller: ContractAddress, order: Order, signature: Span<felt252>);

    fn verifyOrder(self: @TState, order: Order, signer: felt252, signature: Span<felt252>) -> bool;
}


#[starknet::interface]
pub trait IOffchainMessageHash<T> {
    fn get_message_hash(self: @T, order: Order, signer: felt252) -> felt252;
}

#[starknet::interface]
pub trait IOM721Token<T> {
    fn safe_mint(ref self: T, to: ContractAddress, quantity: u256);
}
