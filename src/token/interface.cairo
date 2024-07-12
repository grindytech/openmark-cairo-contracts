 use starknet::{ClassHash, ContractAddress};
 
#[starknet::interface]
pub trait IOpenMarkFactory<T> {
    fn deploy_contract(
        ref self: T, class_hash: ClassHash, calldata: Span<felt252>, salt: felt252
    ) -> ContractAddress;
}

#[starknet::interface]
pub trait IOM721Token<T> {
    fn safe_mint(ref self: T, to: ContractAddress) -> u256;
    fn safe_batch_mint(ref self: T, to: ContractAddress, quantity: u256) -> Span<u256>;

    fn set_base_uri(ref self: T, base_uri: ByteArray);
    fn get_base_uri(self: @T) -> ByteArray;
}