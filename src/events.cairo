use starknet::{ContractAddress};
use openmark::primitives::{OrderType, Order, Bid};
use core::array::{ArrayTrait};

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
    pub order: Order,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidFilled {
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub bids: Span<Bid>,
    #[key]
    pub nftContract: ContractAddress,
    #[key]
    pub tokenIds: Span<u128>,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidCancelled {
    #[key]
    pub who: ContractAddress,
    #[key]
    pub bid: Bid,
}
