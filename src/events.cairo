use starknet::{ContractAddress};
use openmark::primitives::{OrderType, Order};
use core::array::{ArrayTrait, Array};

#[derive(Drop, PartialEq, starknet::Event)]
pub struct OrderFilled {
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub buyer: ContractAddress,
    #[key]
    pub order: Order,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct OrderCancelled {
    #[key]
    pub who: ContractAddress,
    #[key]
    pub option: OrderType,
    #[key]
    pub nftContract: ContractAddress,
    #[key]
    pub tokenId: u128,
    #[key]
    pub price: u128,
    #[key]
    pub salt: felt252,
    #[key]
    pub expiry: u128,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidFilled {
    #[key]
    pub buyer: ContractAddress,
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub nftContract: ContractAddress,
    #[key]
    pub tokenIds: Array::<u128>,
    #[key]
    pub unitPrice: u128,
    #[key]
    pub salt: felt252,
    #[key]
    pub expiry: u128,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidCancelled {
    #[key]
    pub who: ContractAddress,
    #[key]
    pub nftContract: ContractAddress,
    #[key]
    pub tokenIds: Array::<u128>,
    #[key]
    pub unitPrice: u128,
    #[key]
    pub salt: felt252,
    #[key]
    pub expiry: u128,
}
