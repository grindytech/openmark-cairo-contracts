use starknet::{ContractAddress, ClassHash};
use openmark::primitives::typrs::{Stage};

#[starknet::interface]
pub trait ILaunchpad<T> {
    fn updateStages(
        ref self: T,
        stages: Span<Stage>,
        merkleRoots: Span<felt252>
    );

    fn removeStages(stageIds: Span<u128>);

    fn updateWhitelist(stageIds: Span<u128>, merkleRoots: Span<felt252>);

    fn removeWhitelist(stageIds: Span<u128>);

    fn buy(stageId: u128, amount: u32, merkleProof: Span<felt252>);

    fn withdrawSales(tokens: Span<ContractAddress>);
}
