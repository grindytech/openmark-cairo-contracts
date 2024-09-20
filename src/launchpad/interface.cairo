use starknet::{ContractAddress};
use openmark::primitives::types::{Stage, ID, Balance};

#[starknet::interface]
pub trait ILaunchpad<T> {
    fn updateStages(ref self: T, stages: Span<Stage>, merkleRoots: Span<Option<felt252>>);

    fn removeStages(ref self: T, stageIds: Span<ID>);

    fn updateWhitelist(ref self: T, stageIds: Span<ID>, merkleRoots: Span<Option<felt252>>);

    fn removeWhitelist(ref self: T, stageIds: Span<ID>);

    fn buy(ref self: T, stageId: ID, amount: u128, merkleProof: Span<felt252>);
}

#[starknet::interface]
pub trait ILaunchpadProvider<T> {
    fn validateStage(self: @T, stage: Stage);

    fn getStage(self: @T, stageId: ID) -> Stage;

    fn getActiveStage(self: @T, stageId: ID) -> Stage;

    fn getWhitelist(self: @T, stageId: ID) -> Option<felt252>;

    fn getMintedCount(self: @T, stageId: ID) -> u128;

    fn getUserMintedCount(self: @T, minter: ContractAddress, stageId: ID) -> u128;

    fn verifyWhitelist(
        self: @T, merkleRoot: felt252, merkleProof: Span<felt252>, minter: ContractAddress
    ) -> bool;
}

#[starknet::interface]
pub trait ILaunchpadHelper<T> {
    fn setLaunchpadUri(ref self: T, uri: ByteArray);

    fn getLaunchpadUri(self: @T) -> ByteArray;

    fn getFactory(self: @T) -> ContractAddress;

    fn isClosed(self: @T) -> bool;

    fn launchpadDeposit(self: @T) -> (ContractAddress, Balance);
}

#[starknet::interface]
pub trait ILaunchpadManager<T> {
    fn withdrawSales(ref self: T, tokens: Span<ContractAddress>);

    fn closeLaunchpad(ref self: T, tokens: Span<ContractAddress>);
}


#[starknet::interface]
pub trait IOpenLaunchpadProvider<T> {
    fn verifyPaymentToken(self: @T, paymentToken: ContractAddress) -> bool;

    fn getSales(self: @T, stageId: ID) -> Balance;

    fn isClosed(self: @T, stageId: ID) -> bool;

    fn getMaxSalesDuration(self: @T)-> u128;

    fn getCommission(self: @T) -> u32;
}