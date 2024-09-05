use core::option::OptionTrait;
use core::traits::TryInto;

use starknet::{ContractAddress};

use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address,};
use openmark::{
    primitives::types::{Order, Bid, OrderType},
    hasher::interface::{IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait},
};
use openmark::tests::unit::common::{
    TEST_SELLER, TEST_ETH_ADDRESS, TEST_ERC721_ADDRESS, deploy_mock_account
};

fn deploy_mock_hasher() -> ContractAddress {
    let contract = declare("HasherMock").unwrap();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn get_order_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x654e997e1cbb22847cc326f215a1697fc98779141a6483e0c419f0aeed0b9c7;
    let order = Order {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_ETH_ADDRESS.try_into().unwrap(),
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
fn get_bid_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x42793086c598ac82585061162a6eeee3a8b54ec0711b04610501c286e12ef04;
    let bid = Bid {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_ETH_ADDRESS.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    start_cheat_caller_address(contract_address, TEST_SELLER.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_bid_hash(bid, TEST_SELLER);

    assert_eq!(result, message_hash);
}


#[test]
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
        0xe75494836b56da6d28f2c18ee2716cb89ce8438b4c9d0127390feb12433f3d,
        0xfa8533c614eac3b508e14f5cd86ea583cb7e4842938574559e8927696c16fb
    ];

    start_cheat_caller_address(contract_address, TEST_SELLER.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_order(order, TEST_SELLER, signature.span());

    assert_eq!(result, true);
}

#[test]
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
        0x59690b63571efee93f41a750b5e50122dcbd13cdbe153d5c7eac9a9b88b33bf,
        0x66e0f62a9917abf71409ceb81d164e7f2dc3587b4f0bb8c91f85c1b8ee9446a
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_bid(bid, TEST_SELLER, signature.span());

    assert_eq!(result, true);
}

