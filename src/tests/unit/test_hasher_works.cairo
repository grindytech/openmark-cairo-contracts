use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::tests::utils;
use openzeppelin::introspection::interface::ISRC5_ID;

use starknet::{
    ContractAddress, ClassHash, contract_address_const, get_tx_info, get_caller_address,
};

use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address,
};
use openmark::{
    primitives::types::{Order, Bid, OrderType, SignedBid},
    hasher::interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
    },
};


const TEST_ETH_ADDRESS: felt252 = 0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
const TEST_SIGNER: felt252 = 0x913b4e904ab75554db59b64e1d26116d1ba1c033ce57519b53e35d374ef2dd;
const TEST_ERC721_ADDRESS: felt252 =
    0x52D3AA5AF7D5A5D024F99EF80645C32B0E94C9CC4645CDA09A36BE2696257AA;

fn deploy_mock_hasher() -> ContractAddress {
    let contract = declare("HasherMock").unwrap();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}


#[test]
#[available_gas(2000000)]
fn get_order_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x43bb63af60cadf46da9820cb6eacaffea38b26444385d94130d63612740b42d;
    let order = Order {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_ETH_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    start_cheat_caller_address(contract_address, TEST_SIGNER.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_order_hash(order, TEST_SIGNER);

    assert_eq!(result, message_hash);
}

#[test]
#[available_gas(2000000)]
fn get_bid_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x239acfa1717fb6c270513e7c2ce47de2c88e4ef8ea4f0c556184a528c5ad4e1;
    let bid = Bid {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_ETH_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    start_cheat_caller_address(contract_address, TEST_SIGNER.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_bid_hash(bid, TEST_SIGNER);

    assert_eq!(result, message_hash);
}

#[test]
#[available_gas(2000000)]
fn verify_order_works() {
    let contract_address = deploy_mock_hasher();

    let order = Order {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_ETH_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    let mut signature = array![
        0x6edb77859dca36b18d5537cf87d8ffbbd5c0faaea8e05eefc929a07098f2295,
        0x608305c5d0e5b3023260ab978bd9a0a0c52ae1c4f9e3f91a10a753e2d1c442c
    ];

    start_cheat_caller_address(contract_address, TEST_SIGNER.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_order(order, TEST_SIGNER, signature.span());

    assert_eq!(result, true);
}

#[test]
#[available_gas(2000000)]
fn verify_bid_works() {
    let contract_address = deploy_mock_hasher();

    let bid = Bid {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_ETH_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    let mut signature = array![
        0x4ea67a94ac0e95d87bfe2a39cb9728443a56850ced121afbcf0b47877f2edde,
        0x7f0c4be2712170650643257b183d36cc93e13201788e3c45ba946a8622d97cb
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_bid(bid, TEST_SIGNER, signature.span());

    assert_eq!(result, true);
}
