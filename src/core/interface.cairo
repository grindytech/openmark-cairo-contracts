use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Order, OrderType, Bid, SignedBid, Bag};

#[starknet::interface]
pub trait IOpenMark<TState> {
    fn buy(ref self: TState, seller: ContractAddress, order: Order, signature: Span<felt252>);

    fn accept_offer(
        ref self: TState, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn fill_bids(
        ref self: TState,
        bids: Span<SignedBid>,
        nft_token: ContractAddress,
        token_ids: Span<u128>,
        payment_token: ContractAddress,
        asking_price: u128,
    );

    fn cancel_order(ref self: TState, order: Order, signature: Span<felt252>);

    fn cancel_bid(ref self: TState, bid: Bid, signature: Span<felt252>);

    fn batch_buy(ref self: TState, bags: Span<Bag>);
}

#[starknet::interface]
pub trait IOpenMarkCamel<TState> {
    fn acceptOffer(
        ref self: TState, buyer: ContractAddress, order: Order, signature: Span<felt252>
    );

    fn fillBids(
        ref self: TState,
        bids: Span<SignedBid>,
        nftContract: ContractAddress,
        tokenIds: Span<u128>,
        paymentToken: ContractAddress,
        askingPrice: u128,
    );

    fn cancelOrder(ref self: TState, order: Order, signature: Span<felt252>);

    fn cancelBid(ref self: TState, bid: Bid, signature: Span<felt252>);

    fn batchBuy(ref self: TState, bags: Span<Bag>);
}

#[starknet::interface]
pub trait IOpenMarkProvider<TState> {
    fn get_chain_id(self: @TState) -> felt252;
    fn get_commission(self: @TState) -> u32;
    fn verify_payment_token(self: @TState, payment_token: ContractAddress) -> bool;
    fn is_used_signature(self: @TState, signature: Span<felt252>) -> bool;

    fn verify_buy(
        self: @TState,
        order: Order,
        signature: Span<felt252>,
        seller: ContractAddress,
        buyer: ContractAddress
    );
    
    fn verify_accept_offer(
        self: @TState,
        order: Order,
        signature: Span<felt252>,
        seller: ContractAddress,
        buyer: ContractAddress
    );

    fn validate_bid(self: @TState, bid: Bid, bidder: ContractAddress);

    /// Validate the validity of signed bid
    fn validate_signed_bid(self: @TState, bid: SignedBid);

    fn validate_bid_supply(
        self: @TState, seller: ContractAddress, nft_token: ContractAddress, token_ids: Span<u128>
    );

    /// Validate the match of seller and bidder
    fn validate_matching_bid(
        self: @TState,
        bid: Bid,
        nft_token: ContractAddress,
        payment_token: ContractAddress,
        asking_price: u128
    );

    fn validate_signed_bids(self: @TState, bids: Span<SignedBid>);

    fn validate_bid_signature(
        self: @TState, bid: Bid, signer: ContractAddress, signature: Span<felt252>,
    );

    fn get_version(self: @TState) -> (u32, u32, u32);
}

#[starknet::interface]
pub trait IOpenMarkManager<TState> {
    fn set_commission(ref self: TState, new_commission: u32);
    fn add_payment_token(ref self: TState, payment_token: ContractAddress);
    fn remove_payment_token(ref self: TState, payment_token: ContractAddress);
    fn set_max_fill_nfts(ref self: TState, max_nfts: u32);
}
