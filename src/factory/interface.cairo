use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Balance};

#[starknet::interface]
pub trait IOERC721Factory<T> {
    fn createInstance(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        total_supply: u256,
        royalty_percentage: u256,
    );

    fn getInstance(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait IOERC1155Factory<T> {
    fn createInstance(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        uri: ByteArray,
        total_supply: u256,
        royalty_percentage: u256,
    );

    fn getInstance(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait ILaunchpadFactory<T> {
    fn createInstance(ref self: T, id: u256, owner: ContractAddress);

    fn getInstance(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait IFactoryManager<T> {
    fn set_classhash(ref self: T, classhash: ClassHash);
}
