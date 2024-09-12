use starknet::ContractAddress;
use openmark::primitives::types::{Stage, ID, Balance};

#[derive(Drop, PartialEq, starknet::Event)]
pub struct StageUpdated {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub stage: Stage,
    #[key]
    pub merkleRoot: Option<felt252>,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct StageRemoved {
    #[key]
    pub stageId: ID,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct WhitelistUpdated {
    #[key]
    pub stageId: ID,
    #[key]
    pub merkleRoot: Option<felt252>,
}


#[derive(Drop, PartialEq, starknet::Event)]
pub struct WhitelistRemoved {
    #[key]
    pub stageId: ID,
}


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
    pub stageId: ID,
    #[key]
    pub amount: u128,
    pub paymentToken: ContractAddress,
    pub price: Balance,
    pub mintedTokens: Span<u256>,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct LaunchpadClosed {
    #[key]
    pub launchpad: ContractAddress,
    #[key]
    pub owner: ContractAddress,
}
