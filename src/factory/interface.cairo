use starknet::{ContractAddress, ClassHash};
use openmark::primitives::types::{Balance};

#[starknet::interface]
pub trait INFTFactory<T> {
    fn create_collection(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        total_supply: u256,
    );

    fn get_collection(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait INFTFactoryCamel<T> {
    fn createCollection(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        baseURI: ByteArray,
        totalSupply: u256,
    );

    fn getCollection(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait ILaunchpadFactory<T> {
    fn create_launchpad(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        uri: ByteArray,
    );

    fn get_launchpad(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait ILaunchpadFactoryCamel<T> {
    fn createLaunchpad(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        uri: ByteArray,
    );

}

#[starknet::interface]
pub trait INFTFactoryManager<T> {
    fn set_classhash(
        ref self: T,
       classhash: ClassHash
    );
}

#[starknet::interface]
pub trait ILaunchpadFactoryManager<T> {
    fn set_classhash(
        ref self: T,
       classhash: ClassHash
    );


}

#[starknet::interface]
pub trait ILaunchpadFactoryProvider<T> {
    fn getLaunchpad(self: @T, id: u256) -> ContractAddress;

    fn getCommision(
        self: @T,
    )-> u32;

    fn verifyPaymentToken( self: @T,paymentToken: ContractAddress) -> bool;

    fn getLaunchpadLockAmount( self: @T,) -> Balance;

}



