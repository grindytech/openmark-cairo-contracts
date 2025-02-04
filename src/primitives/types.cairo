use starknet::ContractAddress;
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use openmark::primitives::constants::{STARKNET_DOMAIN_TYPE_HASH, ORDER_STRUCT_TYPE_HASH};
use starknet::storage::{Mutable, MutableVecTrait, StorageAsPath, StoragePath, Vec, VecTrait};
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::storage_access::StorePacking;

pub type ID = u128;
pub type Balance = u128;

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
    pub value: u128,
    pub payment: ContractAddress,
    pub price: Balance,
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

#[derive(Copy, PartialEq, Drop, Serde, Debug, starknet::Store)]
pub enum StageType {
     // Buying specific token IDs
    Selector,
    // Batch buying with specific IDs and quantities
    BatchSelector, 
     // Minting fungible tokens
    TokenMint,
    // Buying random token(s)
    Random, 
    // Batch buying with random allocation
    BatchRandom 
}

#[derive(Copy, PartialEq, Drop, Serde, Debug, starknet::Store)]
pub struct Stage {
    pub stageType: StageType,
    pub collection: ContractAddress,
    pub payment: ContractAddress,
    pub price: u256,
    pub maxAllocation: u256,
    pub limit: u256,
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
        state = state.update_with(9);
        state.finalize()
    }
}

pub trait ISignatureHash {
    fn hash_struct() -> felt252;
}
