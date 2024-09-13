use core::option::OptionTrait;
use core::traits::TryInto;

use starknet::{ContractAddress};

use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address,};
use openmark::{
    primitives::types::{Order, Bid, OrderType},
    hasher::interface::{IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait},
};
use openmark::tests::unit::common::{
    SELLER1, TEST_PAYMENT, TEST_NFT, deploy_mock_account
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
    let message_hash = 0x6c4f1857298dec8944276d7c2126e3c19f29801ab41903efa03ff750c8fa8f5;
    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    start_cheat_caller_address(contract_address, SELLER1.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_order_hash(order, SELLER1);
    assert_eq!(result, message_hash);
}

#[test]
fn get_bid_hash_works() {
    let contract_address = deploy_mock_hasher();
    let message_hash = 0x112fac68386d4127199c52ff7be1676fc729161a6113f00e989f3650b309549;
    let bid = Bid {
        nftContract: TEST_NFT.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    start_cheat_caller_address(contract_address, SELLER1.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_bid_hash(bid, SELLER1);

    assert_eq!(result, message_hash);
}


#[test]
fn verify_signature_works() {
    let contract_address = deploy_mock_hasher();
    let message_hash = 0x6c4f1857298dec8944276d7c2126e3c19f29801ab41903efa03ff750c8fa8f5;

    let mut signature = array![
        0x5ef9810b7349fc322d2d58c30a73712a63439ca1557b1d4643abc8d570e9dd7,
        0x65f73bc60f64edbfc923019bbbf9f4e79f941d9585656333cdd615b2cde6b85
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };
    let result = dispatcher.verify_signature(message_hash, SELLER1, signature.span());

    assert_eq!(result, true);
}

#[test]
fn verify_contract_signature_works() {
    let contract_address = deploy_mock_hasher();
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
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    let signature = array![
        0x5ef9810b7349fc322d2d58c30a73712a63439ca1557b1d4643abc8d570e9dd7,
        0x65f73bc60f64edbfc923019bbbf9f4e79f941d9585656333cdd615b2cde6b85
    ];

    start_cheat_caller_address(contract_address, SELLER1.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_order(order, SELLER1, signature.span());

    assert_eq!(result, true);
}

#[test]
fn verify_bid_works() {
    let contract_address = deploy_mock_hasher();

    let bid = Bid {
        nftContract: TEST_NFT.try_into().unwrap(),
        amount: 1,
        unitPrice: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
    };

    let mut signature = array![
        0x395b8788705b19c9cf4f6cae65e7403918e324100aa4e52c5f05816a9cb08c1,
        0x5d716e05d2b234bcb7ecc1ef2864840bcb10d86d031bf0de6f0ad088b2be417
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_bid(bid, SELLER1, signature.span());

    assert_eq!(result, true);
}

