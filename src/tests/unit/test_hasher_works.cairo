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
use openmark::tests::unit::common::{
    ZERO, deploy_mock_account
};

pub const TEST_SELLER: felt252 = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

pub const TEST_NFT_ADDRESS: felt252 =
    0x55FE20463A398171FBDEF9A8DC692E9500D2EBEB8C96D7601D706A253DD8303;

pub const TEST_PAYMENT_ADDRESS: felt252 =
    0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;

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
    let message_hash = 0x654e997e1cbb22847cc326f215a1697fc98779141a6483e0c419f0aeed0b9c7;
    let order = Order {
        nftContract: TEST_NFT_ADDRESS.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_PAYMENT_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    start_cheat_caller_address(contract_address, TEST_SELLER.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_order_hash(order, TEST_SELLER);

    assert_eq!(result, message_hash);
}

#[test]
#[available_gas(2000000)]
fn get_bid_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x42793086c598ac82585061162a6eeee3a8b54ec0711b04610501c286e12ef04;
    let bid = Bid {
        nftContract: TEST_NFT_ADDRESS.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_PAYMENT_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    start_cheat_caller_address(contract_address, TEST_SELLER.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_bid_hash(bid, TEST_SELLER);

    assert_eq!(result, message_hash);
}


#[test]
#[available_gas(2000000)]
fn verify_signature_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x654e997e1cbb22847cc326f215a1697fc98779141a6483e0c419f0aeed0b9c7;

    let mut signature = array![
        0xe75494836b56da6d28f2c18ee2716cb89ce8438b4c9d0127390feb12433f3d,
        0xfa8533c614eac3b508e14f5cd86ea583cb7e4842938574559e8927696c16fb
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };
    let result = dispatcher.verify_signature(message_hash, TEST_SELLER, signature.span());

    assert_eq!(result, true);
}

#[test]
#[available_gas(2000000)]
fn verify_contract_signature_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 1;

    let mut signature = array![1, 2];

    let account = deploy_mock_account();

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_signature(message_hash, account.into(), signature.span());

    assert_eq!(result, true);
}


#[test]
#[available_gas(2000000)]
fn verify_order_works() {
    let contract_address = deploy_mock_hasher();

    let order = Order {
        nftContract: TEST_NFT_ADDRESS.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_PAYMENT_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    let mut signature = array![
        0xe75494836b56da6d28f2c18ee2716cb89ce8438b4c9d0127390feb12433f3d,
        0xfa8533c614eac3b508e14f5cd86ea583cb7e4842938574559e8927696c16fb
    ];

    start_cheat_caller_address(contract_address, TEST_SELLER.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_order(order, TEST_SELLER, signature.span());

    assert_eq!(result, true);
}

#[test]
#[available_gas(2000000)]
fn verify_bid_works() {
    let contract_address = deploy_mock_hasher();

    let bid = Bid {
        nftContract: TEST_NFT_ADDRESS.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_PAYMENT_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    let mut signature = array![
        0x59690b63571efee93f41a750b5e50122dcbd13cdbe153d5c7eac9a9b88b33bf,
        0x66e0f62a9917abf71409ceb81d164e7f2dc3587b4f0bb8c91f85c1b8ee9446a
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_bid(bid, TEST_SELLER, signature.span());

    assert_eq!(result, true);
}

