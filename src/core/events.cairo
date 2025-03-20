// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use starknet::{ContractAddress};
use openmark::primitives::types::{Order};

/// Emitted when a trade is filled. This event is triggered when an order is made,
/// which can be either a buy_nft or accept_offer.
#[derive(Drop, PartialEq, starknet::Event)]
pub struct OrderFilled {
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub buyer: ContractAddress,
    #[key]
    pub order: Order,
}

/// Emitted when an order is canceled.
#[derive(Drop, PartialEq, starknet::Event)]
pub struct OrderCancelled {
    #[key]
    pub who: ContractAddress,
    #[key]
    pub order: Order,
}