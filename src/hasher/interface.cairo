use openmark::primitives::types::{Order, Bid, SignedBid};
use starknet::account::Call;

#[starknet::interface]
pub trait IOffchainMessageHash<T> {
    fn get_order_hash(self: @T, order: Order, signer: felt252) -> felt252;
    fn get_bid_hash(self: @T, bid: Bid, signer: felt252) -> felt252;

    fn verify_order(self: @T, order: Order, signer: felt252, signature: Span<felt252>) -> bool;
    fn verify_bid(self: @T, bid: Bid, signer: felt252, signature: Span<felt252>) -> bool;
    fn verify_signature(self: @T, hash: felt252, signer: felt252, signature: Span<felt252>) -> bool;
    fn hash_array(self: @T, value: Span<felt252>) -> felt252;
}


// Import Argent account interface
#[starknet::interface]
pub trait IAccount<T> {
    fn __validate__(ref self: T, calls: Array<Call>) -> felt252;
    fn __execute__(ref self: T, calls: Array<Call>) -> Array<Span<felt252>>;

    /// @notice Checks whether a given signature for a given hash is valid
    /// @dev Warning: To guarantee the signature cannot be replayed in other accounts or other chains, the data hashed must be unique to the account and the chain.
    /// This is true today for starknet transaction signatures and for SNIP-12 signatures but might not be true for other types of signatures
    /// @param hash The hash of the data to sign
    /// @param signature The signature to validate
    /// @return The shortstring 'VALID' when the signature is valid, 0 if the signature doesn't match the hash
    /// @dev it can also panic if the signature is not in a valid format
    fn is_valid_signature(self: @T, hash: felt252, signature: Array<felt252>) -> felt252;
}