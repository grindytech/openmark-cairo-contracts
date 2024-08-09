pub const MINTER_ROLE: felt252 = 'MINTER_ROL';

pub const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

pub const ORDER_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "Order(nftContract:ContractAddress,tokenId:u128,payment:ContractAddress,price:u128,salt:felt,expiry:u128,option:OrderType)"
    );

pub const BID_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "Bid(nftContract:ContractAddress,amount:u128,payment:ContractAddress,unitPrice:u128,salt:felt,expiry:u128)"
    );