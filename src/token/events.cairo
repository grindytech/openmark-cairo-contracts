use starknet::ContractAddress;

#[derive(Drop, PartialEq, starknet::Event)]
pub struct TokenMinted {
    #[key]
    pub to: ContractAddress,
    #[key]
    pub token_id: u256,
    #[key]
    pub uri: ByteArray,
}

#[derive(Drop, PartialEq, starknet::Event)]
pub struct TokenURIUpdated {
    #[key]
    pub token_id: u256,
    #[key]
    pub uri: ByteArray,
}
