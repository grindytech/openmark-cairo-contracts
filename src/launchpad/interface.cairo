use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Stage};

#[starknet::interface]
pub trait ILaunchpad<T> {
    fn updateStages(ref self: T, stages: Span<Stage>, merkleRoots: Span<felt252>);

    fn removeStages(ref self: T, stageIds: Span<u128>);

    fn updateWhitelist(ref self: T, stageIds: Span<u128>, merkleRoots: Span<felt252>);

    fn removeWhitelist(ref self: T, stageIds: Span<u128>);

    fn buy(ref self: T, stageId: u128, amount: u32, merkleProof: Span<felt252>);

    fn withdrawSales(ref self: T, tokens: Span<ContractAddress>);
}

#[starknet::interface]
pub trait ILaunchpadProvider<T> {
    fn getStage(self: @T, stageId: u128) -> Stage;

    fn getActiveStage(self: @T, stageId: u128) -> Stage;

    fn getWhitelist(self: @T, stageId: u128) -> Option<felt252>;

    fn getMintedCount(self: @T, stageId: u128) -> u128;

    fn getUserMintedCount(self: @T, minter: ContractAddress, stageId: u128) -> u128;

    fn verifyWhitelist(
        self: @T,
        merkleRoot: felt252,
        merkleProof: Span<felt252>,
        minter: ContractAddress
    ) -> bool;
}
