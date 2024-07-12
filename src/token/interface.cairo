 use starknet::{ClassHash, ContractAddress};
 
#[starknet::interface]
pub trait IOpenMarkFactory<T> {
    fn deploy_contract(
        ref self: T, class_hash: ClassHash, calldata: Span<felt252>, salt: felt252
    ) -> ContractAddress;
}

#[starknet::interface]
pub trait IOpenMarkNFT<T> {
    fn safe_mint(ref self: T, to: ContractAddress);
    fn safe_mint_with_uri(ref self: T, to: ContractAddress, uri: ByteArray);

    fn safe_batch_mint(ref self: T, to: ContractAddress, quantity: u256);
    fn safe_batch_mint_with_uris(ref self: T, to: ContractAddress, uris: Span<ByteArray>);

    fn set_token_uri(ref self: T, token_id: u256, uri: ByteArray);
    fn get_token_uri(self: @T, token_id: u256) -> ByteArray;
}