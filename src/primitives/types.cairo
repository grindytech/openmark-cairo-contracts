use starknet::ContractAddress;
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use core::fmt::Debug;

pub const ETH_CONTRACT_ADDRESS: felt252 =
    0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;

pub const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

pub const ORDER_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "Order(nftContract:ContractAddress,tokenId:u128,payment:ContractAddress,price:u128,salt:felt,expiry:u128,option:OrderType)"
    );

pub const BID_STRUCT_TYPE_HASH: felt252 =
    selector!("Bid(nftContract:ContractAddress,amount:u128,payment:ContractAddress,unitPrice:u128,salt:felt,expiry:u128)");

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
