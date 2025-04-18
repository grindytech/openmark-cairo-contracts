// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use starknet::{ContractAddress};

#[starknet::interface]
pub trait IERC721Minter<T> {
    // Original Functions
    fn mint(ref self: T, to: ContractAddress, tokenId: u256);
    fn safe_mint(ref self: T, to: ContractAddress, tokenId: u256, data: Span<felt252>);
    fn mint_batch(ref self: T, to: ContractAddress, tokenIds: Span<u256>);
    fn safe_mint_batch(ref self: T, to: ContractAddress, tokenIds: Span<u256>, data: Span<felt252>);

    // Additional OpenMark Compatible Functions
    fn safeMint(ref self: T, to: ContractAddress, tokenId: u256, data: Span<felt252>);
    fn mintBatch(ref self: T, to: ContractAddress, tokenIds: Span<u256>);
    fn safeMintBatch(ref self: T, to: ContractAddress, tokenIds: Span<u256>, data: Span<felt252>);
}

#[starknet::interface]
pub trait IOERC721Handler<T> {
    fn setBaseURI(ref self: T, newBaseURI: ByteArray, newMaxTokenId: u256);
    fn baseURI(self: @T) -> ByteArray;
    fn getMaxTokenId(self: @T) -> u256;

    fn setRoyalty(ref self: T, royaltyPercentage: u256, royaltyReceiver: ContractAddress);
    fn getRoyalty(self: @T) -> (u256, ContractAddress);
}

#[starknet::interface]
pub trait IERC1155Minter<T> {
    fn mint(ref self: T, to: ContractAddress, tokenId: u256, value: u256, data: Span<felt252>);
    fn mint_batch(
        ref self: T,
        to: ContractAddress,
        tokenIds: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>,
    );
    fn mintBatch(
        ref self: T,
        to: ContractAddress,
        tokenIds: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>,
    );
}

#[starknet::interface]
pub trait IOERC1155Handler<T> {
    fn name(self: @T) -> ByteArray;
    fn symbol(self: @T) -> ByteArray;

    fn setURI(ref self: T, newBaseURI: ByteArray, newMaxTokenId: u256);
    fn tokenURI(self: @T, tokenId: u256) -> ByteArray;
    fn getMaxTokenId(self: @T) -> u256;

    fn setRoyalty(ref self: T, royaltyPercentage: u256, royaltyReceiver: ContractAddress);
    fn getRoyalty(self: @T) -> (u256, ContractAddress);
}

#[starknet::interface]
pub trait IOpenCollection<T> {
    fn mint_uris(ref self: T, to: ContractAddress, uris: Span<ByteArray>);
    fn mintURIs(ref self: T, to: ContractAddress, uris: Span<ByteArray>);
    fn getTokenIndex(self: @T) -> u256;
}
