// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use starknet::{ContractAddress};
use openmark::primitives::types::{Order, Bag};

#[starknet::interface]
pub trait IOpenMark<T> {
    fn buy(ref self: T, seller: ContractAddress, order: Order, signature: Span<felt252>);

    fn accept_offer(
        ref self: T, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn buy_with_value(ref self: T, seller: ContractAddress, order: Order, value:u128, signature: Span<felt252>);

    fn accept_offer_with_value(
        ref self: T, buyer: ContractAddress, order: Order, value: u128, signature: Span<felt252>
    );


    fn cancel_order(ref self: T, order: Order, signature: Span<felt252>);

    fn batch_buy(ref self: T, bags: Span<Bag>);
}

#[starknet::interface]
pub trait IOpenMarkCamel<T> {
    fn acceptOffer(
        ref self: T, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn cancelOrder(ref self: T, order: Order, signature: Span<felt252>);

    fn batchBuy(ref self: T, bags: Span<Bag>);
}

#[starknet::interface]
pub trait IOpenMarkProvider<T> {
    fn getChainId(self: @T) -> felt252;
    fn getCommission(self: @T) -> u256;
    fn isUsedSignature(self: @T, signature: Span<felt252>) -> bool;

    fn verifyBuy(
        self: @T,
        order: Order,
        signature: Span<felt252>,
        seller: ContractAddress,
        buyer: ContractAddress
    );

    fn verifyAcceptOffer(
        self: @T,
        order: Order,
        signature: Span<felt252>,
        seller: ContractAddress,
        buyer: ContractAddress
    );

    fn getVersion(self: @T) -> (u32, u32, u32);
}

#[starknet::interface]
pub trait IOpenMarkManager<T> {
    fn set_commission(ref self: T, new_commission: u256);
    fn set_max_royalty(ref self: T, new_royalty: u256);
}
