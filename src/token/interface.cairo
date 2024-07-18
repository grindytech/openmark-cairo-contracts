use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IOpenMarkFactory<T> {
    fn create_collection(
       ref self: T,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    );

    fn set_openmark_nft(ref self: T, classhash: ClassHash);
}

#[starknet::interface]
pub trait IOpenMarkNFT<T> {
    fn safe_mint(ref self: T, to: ContractAddress);
    fn safe_mint_with_uri(ref self: T, to: ContractAddress, uri: ByteArray);

    fn safe_batch_mint(ref self: T, to: ContractAddress, quantity: u256);
    fn safe_batch_mint_with_uris(ref self: T, to: ContractAddress, uris: Span<ByteArray>);

    fn set_token_uri(ref self: T, token_id: u256, uri: ByteArray);
    fn set_base_uri(ref self: T, base_uri: ByteArray);
}

#[starknet::interface]
pub trait IOpenMarNFTkMetadata<T> {
    fn name(self: @T) -> ByteArray;
    fn symbol(self: @T) -> ByteArray;
    fn token_uri(self: @T, token_id: u256) -> ByteArray;
}

#[starknet::interface]
pub trait IOpenMarkNFTMetadataCamelOnly<T> {
    fn tokenURI(self: @T, tokenId: u256) -> ByteArray;
}
