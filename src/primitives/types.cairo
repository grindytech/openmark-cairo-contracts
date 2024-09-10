use starknet::ContractAddress;
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use openmark::primitives::constants::{
    STARKNET_DOMAIN_TYPE_HASH, ORDER_STRUCT_TYPE_HASH, BID_STRUCT_TYPE_HASH
};

#[derive(Drop, Copy, Hash)]
pub struct StarknetDomain {
    pub name: felt252,
    pub version: felt252,
    pub chain_id: felt252,
}

#[derive(Copy, PartialEq, Drop, Serde, Hash)]
pub enum OrderType {
    Buy,
    Offer,
}

#[derive(Copy, PartialEq, Drop, Serde, Hash)]
pub struct Order {
    pub nftContract: ContractAddress,
    pub tokenId: u128,
    pub payment: ContractAddress,
    pub price: u128,
    pub salt: felt252,
    pub expiry: u128,
    pub option: OrderType,
}

#[derive(Copy, PartialEq, Drop, Serde)]
pub struct Bag {
    pub seller: ContractAddress,
    pub order: Order,
    pub signature: Span<felt252>,
}

#[derive(Copy, Drop, Serde)]
pub struct SignedBid {
    pub bidder: ContractAddress,
    pub bid: Bid,
    pub signature: Span<felt252>,
}

#[derive(Copy, PartialEq, Drop, Serde, Hash, Debug)]
pub struct Bid {
    pub nftContract: ContractAddress,
    pub amount: u128,
    pub payment: ContractAddress,
    pub unitPrice: u128,
    pub salt: felt252,
    pub expiry: u128,
}

#[derive(Copy, PartialEq, Drop, Serde, Hash, Debug, starknet::Store)]
pub struct Stage {
    pub id: u128,
    pub collection: ContractAddress,
    pub payment: ContractAddress,
    pub price: u128,
    pub maxAllocation: u128,
    pub limit: u128,
    pub startTime: u128,
    pub endTime: u128,
}

pub trait IStructHash<T> {
    fn hash_struct(self: @T) -> felt252;
}

impl StructHashStarknetDomain of IStructHash<StarknetDomain> {
    fn hash_struct(self: @StarknetDomain) -> felt252 {
        let mut state = PedersenTrait::new(0);
        state = state.update_with(STARKNET_DOMAIN_TYPE_HASH);
        state = state.update_with(*self);
        state = state.update_with(4);
        state.finalize()
    }
}

impl StructHashOrder of IStructHash<Order> {
    fn hash_struct(self: @Order) -> felt252 {
        let mut state = PedersenTrait::new(0);
        state = state.update_with(ORDER_STRUCT_TYPE_HASH);
        state = state.update_with(*self);
        state = state.update_with(8);
        state.finalize()
    }
}

impl StructHashBid of IStructHash<Bid> {
    fn hash_struct(self: @Bid) -> felt252 {
        let mut state = PedersenTrait::new(0);
        state = state.update_with(BID_STRUCT_TYPE_HASH);
        state = state.update_with(*self);
        state = state.update_with(7);
        state.finalize()
    }
}

pub trait ISignatureHash {
    fn hash_struct() -> felt252;
}
