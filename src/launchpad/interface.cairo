// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Stage, DropEntry};

#[starknet::interface]
pub trait IStageSelector<T> {
    fn buy(ref self: T, tokenIds: Span<u256>, merkleProof: Span<felt252>);

    fn withdrawSales(ref self: T);

    fn closeStage(ref self: T);
}

#[starknet::interface]
pub trait IStageBatchSelector<T> {
    fn buy(ref self: T, tokenIds: Span<u256>, values: Span<u256>, merkleProof: Span<felt252>);

    fn withdrawSales(ref self: T);

    fn closeStage(ref self: T);
}


#[starknet::interface]
pub trait IOStage<T> {
    fn getInstance(self: @T) -> Stage;

    fn getMintedCount(self: @T) -> u256;

    fn getUserMintedCount(self: @T, minter: ContractAddress) -> u256;

    fn validateStage(self: @T) -> bool;

    fn validateWhitelist(self: @T, minter: ContractAddress, merkleProof: Span<felt252>) -> bool;
}

#[starknet::interface]
pub trait ILaunchpadProvider<T> {
    fn getConfig(self: @T) -> (u32, ClassHash, ClassHash, ClassHash);
}

#[derive(Drop, Copy, Clone, Serde)]
pub enum Source {
    Nonce: ContractAddress,
    Salt: felt252,
}

#[starknet::interface]
pub trait IVrfProvider<TContractState> {
    fn request_random(self: @TContractState, caller: ContractAddress, source: Source);
    fn consume_random(ref self: TContractState, source: Source) -> felt252;
}

#[starknet::interface]
pub trait IStageVRF<T> {
    fn setup(ref self: T, drop_table: Span<DropEntry>);
    fn buy(ref self: T, mintAmount: u256, merkleProof: Span<felt252>);
    fn withdrawSales(ref self: T);
    fn closeStage(ref self: T);

    // getters
    fn get_drop_table(self: @T) -> Span<DropEntry>;
    fn get_drop_table_entry(self: @T, index: u32) -> DropEntry;
    fn get_drop_table_length(self: @T) -> u32;
    fn get_total_weight(self: @T) -> u128;
    fn get_vrf_provider(self: @T) -> ContractAddress;
}