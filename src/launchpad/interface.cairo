use starknet::{ContractAddress};
use openmark::primitives::types::{Stage, ID, Balance};


#[starknet::interface]
pub trait ILaunchpad<T> {
    fn createStage(
        ref self: T, id: ID, stage: Stage, rootWhitelist: Option::<felt252>, collectionWhitelists: Span<ContractAddress>,
    );

    fn validateStage(self: @T, stage: Stage, owner: ContractAddress); 
}

#[starknet::interface]
pub trait IStageSelector<T> {
    fn buy(
        ref self: T, tokenIds: Span<u256>, merkleProof: Span<felt252>
    );
}

#[starknet::interface]
pub trait IStageBatchSelector<T> {
    fn buy(
        ref self: T, tokenIds: Span<u256>, values: Span<u256>, merkleProof: Span<felt252>
    );
}

#[starknet::interface]
pub trait IOStage<T> {
    fn getStage(self: @T) -> Stage;

    fn getMintedCount(self: @T) -> u256;

    fn getUserMintedCount(self: @T, minter: ContractAddress) -> u256;

    fn validateStage(self: @T)-> bool;

    fn validateWhitelist(self: @T, minter: ContractAddress, merkleProof: Span<felt252>)-> bool;
}

#[starknet::interface]
pub trait ILaunchpadManager<T> {
    fn withdrawSales(ref self: T, tokens: Span<ContractAddress>);

    fn closeLaunchpad(ref self: T, tokens: Span<ContractAddress>);
}