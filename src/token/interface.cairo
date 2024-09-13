use starknet::{ContractAddress};

#[starknet::interface]
pub trait IOpenMarkNFT<T> {
    fn safe_batch_mint(ref self: T, to: ContractAddress, quantity: u256) -> Span<u256>;

    fn safe_batch_mint_with_uris(
        ref self: T, to: ContractAddress, uris: Span<ByteArray>
    ) -> Span<u256>;
}

#[starknet::interface]
pub trait IOpenMarkNFTCamel<T> {
    fn safeBatchMint(ref self: T, to: ContractAddress, quantity: u256) -> Span<u256>;
    fn safeBatchMintWithURIs(ref self: T, to: ContractAddress, uris: Span<ByteArray>) -> Span<u256>;
}

#[starknet::interface]
pub trait IOMERC721<T> {
    fn name(self: @T) -> ByteArray;
    fn symbol(self: @T) -> ByteArray;
    fn token_uri(self: @T, token_id: u256) -> ByteArray;
    fn current_mint_index(self: @T) -> u256;
}

#[starknet::interface]
pub trait IOpenMarkNFTMetadataCamel<T> {
    fn tokenURI(self: @T, tokenId: u256) -> ByteArray;
}
