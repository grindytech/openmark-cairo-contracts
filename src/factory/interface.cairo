use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IOpenMarkFactory<T> {
    fn create_collection(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    );

    fn get_collection(self: @T, id: u256) -> ContractAddress;
}


#[starknet::interface]
pub trait IOpenMarkFactoryCamel<T> {
    fn createCollection(
        ref self: T,
        id: u256,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        baseURI: ByteArray,
    );

    fn getCollection(self: @T, id: u256) -> ContractAddress;
}

#[starknet::interface]
pub trait IFactoryManager<T> {
    fn set_collection_classhash(
        ref self: T,
       classhash: ClassHash
    );
}

