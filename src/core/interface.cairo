use starknet::{ContractAddress};
use openmark::primitives::types::{Order, Bag};

#[starknet::interface]
pub trait IOpenMark<TState> {
    fn buy(ref self: TState, seller: ContractAddress, order: Order, signature: Span<felt252>);

    fn accept_offer(
        ref self: TState, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn buy_with_value(ref self: TState, seller: ContractAddress, order: Order, value:u128, signature: Span<felt252>);

    fn accept_offer_with_value(
        ref self: TState, buyer: ContractAddress, order: Order, value: u128, signature: Span<felt252>
    );


    fn cancel_order(ref self: TState, order: Order, signature: Span<felt252>);

    fn batch_buy(ref self: TState, bags: Span<Bag>);
}

#[starknet::interface]
pub trait IOpenMarkCamel<TState> {
    fn acceptOffer(
        ref self: TState, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn cancelOrder(ref self: TState, order: Order, signature: Span<felt252>);

    fn batchBuy(ref self: TState, bags: Span<Bag>);
}

#[starknet::interface]
pub trait IOpenMarkProvider<TState> {
    fn getChainId(self: @TState) -> felt252;
    fn getCommission(self: @TState) -> u32;
    fn verifyPaymentToken(self: @TState, paymentToken: ContractAddress) -> bool;
    fn isUsedSignature(self: @TState, signature: Span<felt252>) -> bool;

    fn verifyBuy(
        self: @TState,
        order: Order,
        signature: Span<felt252>,
        seller: ContractAddress,
        buyer: ContractAddress
    );

    fn verifyAcceptOffer(
        self: @TState,
        order: Order,
        signature: Span<felt252>,
        seller: ContractAddress,
        buyer: ContractAddress
    );

    fn getVersion(self: @TState) -> (u32, u32, u32);
}

#[starknet::interface]
pub trait IOpenMarkManager<TState> {
    fn set_commission(ref self: TState, new_commission: u32);
    fn add_payment_token(ref self: TState, payment_token: ContractAddress);
    fn remove_payment_token(ref self: TState, payment_token: ContractAddress);
}
