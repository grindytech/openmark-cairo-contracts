use starknet::ContractAddress;
use openmark::primitives::types::{Stage, ID, Balance};

#[derive(Drop, PartialEq, starknet::Event)]
pub struct SalesWithdrawn {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub tokenPayment: ContractAddress,
    #[key]
    pub amount: Balance,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct TokensBought {
    #[key]
    pub buyer: ContractAddress,
    #[key]
    pub amount: u256,
    pub paymentToken: ContractAddress,
    pub price: u256,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct LaunchpadClosed {
    #[key]
    pub launchpad: ContractAddress,
    #[key]
    pub owner: ContractAddress,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct StageCreated {
    #[key]
    pub id: ID,
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub stage: Stage,
    pub rootWhitelist: Option::<felt252>,
    pub collectionWhitelists: Span<ContractAddress>,
    pub commission: u32,
}
