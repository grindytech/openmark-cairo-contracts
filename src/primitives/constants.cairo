pub const MINTER_ROLE: felt252 = 'MINTER_ROLE';
pub const PERMYRIAD: u256 = 10000;

pub const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

pub const ORDER_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "Order(nftContract:ContractAddress,tokenId:u128,value:u128,payment:ContractAddress,price:u128,salt:felt,expiry:u128,option:OrderType)"
    );
