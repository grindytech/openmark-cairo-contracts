use core::option::OptionTrait;
use core::traits::TryInto;

use starknet::{ContractAddress};

use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address, DeclareResultTrait};
use openmark::{
    primitives::types::{Order, OrderType},
    hasher::interface::{IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait},
};
use openmark::tests::unit::common::{SELLER1, TEST_PAYMENT, TEST_NFT, deploy_mock_account};

fn deploy_mock_hasher() -> ContractAddress {
    let contract = declare("HasherMock").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn get_order_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x5edc47e184d0e3d88508282e829c4b8258ea7eb952e814e3313c17dd9d22189;
    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 2,
        value: 1,
        price: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    start_cheat_caller_address(contract_address, SELLER1.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_order_hash(order, SELLER1);
    assert(result == message_hash, 'Order hash not correct');
}

#[test]
fn verify_signature_works() {
    let contract_address = deploy_mock_hasher();
    let message_hash = 0x5edc47e184d0e3d88508282e829c4b8258ea7eb952e814e3313c17dd9d22189;

    let mut signature = array![
        0x3358bee5f4f2357907a7e5f0f71df53813264ef62dc99f2954a661d8c60085e,
        0x3c8c95d75ec7f9e13f70ef2b74ce9e45c2a66ff390b9732c002319b5eb19bfb
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };
    let result = dispatcher.verify_signature(message_hash, SELLER1, signature.span());

    assert(result, 'Verify signature failed');
}

#[test]
fn verify_contract_signature_works() {
    let contract_address = deploy_mock_hasher();
    let message_hash = 1;

    let mut signature = array![1, 2];

    let account = deploy_mock_account();

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_signature(message_hash, account.into(), signature.span());

    assert(result, 'Verify contract account failed');
}


#[test]
fn verify_order_works() {
    let contract_address = deploy_mock_hasher();

    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 2,
        value: 1,
        price: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    let signature = array![
        0x3358bee5f4f2357907a7e5f0f71df53813264ef62dc99f2954a661d8c60085e,
        0x3c8c95d75ec7f9e13f70ef2b74ce9e45c2a66ff390b9732c002319b5eb19bfb
    ];

    start_cheat_caller_address(contract_address, SELLER1.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_order(order, SELLER1, signature.span());

    assert(result, 'Verify order failed');
}


#[test]
fn verify_order_value_works() {
    let contract_address = deploy_mock_hasher();

    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 2,
        value: 10,
        price: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    let signature = array![
        0x483f9a732042df50d80d7dd1363894bc924a7c3181027a611fdd90085730dc3,
        0x25fa6058f6c6859bcf604a37b3515485ad0937cab485715c81f36f4fd5e3f6a
    ];

    start_cheat_caller_address(contract_address, SELLER1.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_order(order, SELLER1, signature.span());

    assert(result, 'Verify order failed');
}