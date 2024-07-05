use starknet::{ContractAddress};
use openmark::primitives::{OrderType, Order, Bid};
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

/// Emit when bids is filled
#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidsFilled {
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub bids: Span<Bid>,
    #[key]
    pub nftContract: ContractAddress,
    #[key]
    pub tokenIds: Span<u128>,
}

/// Emitted when a bid is canceled.
#[derive(Drop, PartialEq, starknet::Event)]
pub struct BidCancelled {
    #[key]
    pub who: ContractAddress,
    #[key]
    pub bid: Bid,
}
