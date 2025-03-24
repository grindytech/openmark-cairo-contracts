// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IOERC721Factory<T> {
    fn createInstance(
        ref self: T,
        id: u256,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        max_token_id: u256,
        royalty_percentage: u256,
    );

    fn getInstance(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait IOERC1155Factory<T> {
    fn createInstance(
        ref self: T,
        id: u256,
        name: ByteArray,
        symbol: ByteArray,
        uri: ByteArray,
        max_token_id: u256,
        royalty_percentage: u256,
    );

    fn getInstance(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait ILaunchpadFactory<T> {
    fn createInstance(ref self: T, id: u256);

    fn getInstance(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait IFactoryManager<T> {
    fn set_classhash(ref self: T, classhash: ClassHash);
}
