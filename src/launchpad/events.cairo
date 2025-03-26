// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use starknet::ContractAddress;

#[derive(Drop, PartialEq, starknet::Event)]
pub struct SalesWithdrawn {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub tokenPayment: ContractAddress,
    #[key]
    pub amount: u256,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct TokensBought {
    #[key]
    pub buyer: ContractAddress,
    #[key]
    pub amount: u256,
    pub paymentToken: ContractAddress,
    pub price: u256,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct StageClosed {
    #[key]
    pub caller: ContractAddress,
}
