use starknet::{ContractAddress};
use openmark::primitives::types::{Stage, ID, Balance};


#[starknet::interface]
pub trait ILaunchpadProvider<T> {
    fn validateStage(self: @T, stage: Stage, owner: ContractAddress);

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
pub trait ILaunchpad<T> {
    fn createStage(
        ref self: T, id: ID, stage: Stage
    );

    fn validateStage(self: @T, stage: Stage, owner: ContractAddress); 
}

#[starknet::interface]
pub trait IStageSelector<T> {
    fn buy(
        ref self: T, tokenIds: Span<u256>, values: Option<Span<u256>>, merkleProof: Span<felt252>
    );
}

#[starknet::interface]
pub trait IOStage<T> {
    fn getStage(self: @T) -> Stage;

    fn getMintedCount(self: @T) -> u128;

    fn getUserMintedCount(self: @T, minter: ContractAddress) -> u128;

    fn validateStage(self: @T)-> bool;

    fn validateWhitelist(self: @T, minter: ContractAddress, merkleProof: Span<felt252>)-> bool;
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

    fn getMaxSalesDuration(self: @T) -> u128;

    fn getCommission(self: @T) -> u32;
}

#[starknet::interface]
pub trait IOpenLaunchpadManager<T> {
    fn withdrawSales(ref self: T, stageId: ID);
}
