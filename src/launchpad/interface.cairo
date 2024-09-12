use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Stage, ID};

#[starknet::interface]
pub trait ILaunchpad<T> {
    fn updateStages(ref self: T, stages: Span<Stage>, merkleRoots: Span<Option::<felt252>>);

    fn removeStages(ref self: T, stageIds: Span<ID>);

    fn updateWhitelist(ref self: T, stageIds: Span<ID>, merkleRoots: Span<Option::<felt252>>);

    fn removeWhitelist(ref self: T, stageIds: Span<ID>);

    fn buy(ref self: T, stageId: ID, amount: u128, merkleProof: Span<felt252>);

    fn withdrawSales(ref self: T, tokens: Span<ContractAddress>);

    fn closeLaunchpad(ref self: T, tokens: Span<ContractAddress>);
}

#[starknet::interface]
pub trait ILaunchpadProvider<T> {
    fn getStage(self: @T, stageId: ID) -> Stage;

    fn getActiveStage(self: @T, stageId: ID) -> Stage;

    fn getWhitelist(self: @T, stageId: ID) -> Option<felt252>;

    fn getMintedCount(self: @T, stageId: ID) -> u128;

    fn getUserMintedCount(self: @T, minter: ContractAddress, stageId: ID) -> u128;

    fn verifyWhitelist(
        self: @T,
        merkleRoot: felt252,
        merkleProof: Span<felt252>,
        minter: ContractAddress
    ) -> bool;
}
