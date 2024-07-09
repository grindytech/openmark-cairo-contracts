use starknet::{ContractAddress, ClassHash};
use openmark::primitives::{Order, Bid, SignedBid};

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


#[starknet::interface]
pub trait IOffchainMessageHash<T> {
    fn get_order_hash(self: @T, order: Order, signer: felt252) -> felt252;
    fn get_bid_hash(self: @T, bid: Bid, signer: felt252) -> felt252;

    fn verify_order(self: @T, order: Order, signer: felt252, signature: Span<felt252>) -> bool;
    fn verify_bid(self: @T, bid: Bid, signer: felt252, signature: Span<felt252>) -> bool;
}

#[starknet::interface]
pub trait IOM721Token<T> {
    fn safe_mint(ref self: T, to: ContractAddress) -> u256;
    fn safe_batch_mint(ref self: T, to: ContractAddress, quantity: u256) -> Span<u256>;

    fn set_base_uri(ref self: T, base_uri: ByteArray);
    fn get_base_uri(self: @T) -> ByteArray;
}

#[starknet::interface]
pub trait IOpenMarkFactory<T> {
    fn deploy_contract(
        ref self: T, class_hash: ClassHash, calldata: Span<felt252>, salt: felt252
    ) -> ContractAddress;
}