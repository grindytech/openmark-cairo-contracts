use starknet::{ContractAddress};
use openmark::primitives::types::{OrderType, Order, Bid};
use core::array::{ArrayTrait};


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

/// Event emitted when a bid is filled in OpenMark.
/// 
/// Variables:
/// - `seller`: The address of the seller who accepted the bid.
/// - `bidder`: The address of the bidder who placed the bid.
/// - `bid`: The details of the bid, encapsulated in the `Bid` struct.
/// - `tokenIds`: A list of token IDs were traded.
/// - `askingPrice`: The price at which the bid was accepted.
///
/// This event provides key information about the transaction, enabling listeners to
/// track successful bids and their associated details.
#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidFilled {
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub bidder: ContractAddress,
    #[key]
    pub bid: Bid,
    #[key]
    pub tokenIds: Span<u128>,
    #[key]
    pub askingPrice: u128,
}

/// Emitted when a bid is canceled.
#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidCancelled {
    #[key]
    pub who: ContractAddress,
    #[key]
    pub bid: Bid,
}
