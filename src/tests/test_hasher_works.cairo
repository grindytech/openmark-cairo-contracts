use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use openzeppelin::tests::utils::constants::OWNER;
use openzeppelin::utils::serde::SerializedAppend;

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address
};
use openmark::{
    primitives::{Order, Bid, OrderType, SignedBid},
    interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOM721TokenDispatcher
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
    let message_hash = 0x2575f63956fb4a09d651d372072a90b8f616d79c67c17e70223b04158a5a65e;
    let order = Order {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(),
        tokenId: 2,
        price: 3,
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
    let message_hash = 0x6508e40ab567863c5d768e30c6d35aa5837c7150588e1794ec76f3675a8d151;
    let bid = Bid {
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(), amount: 1, unitPrice: 3, salt: 4, expiry: 5,
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
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    let mut signature = array![
        0x731246d027886090a219c7a75469db89468d416f794020d7e8bd0a34858638d,
        0xec12683f031e33fdd302b15259fc398f58f2786473aa8528546a129a7c3e4f
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
        nftContract: TEST_ERC721_ADDRESS.try_into().unwrap(), amount: 1, unitPrice: 3, salt: 4, expiry: 5,
    };

    let mut signature = array![
        0x3c0ac7eca879533ffd6de6b6ef8630889a92b6f55844b4aefdb037443018c4d,
        0x43ce88b1de27d39b8f8a88fc378792cacb39b67099161c835f66c5ddefe7ddd
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verify_bid(bid, TEST_SIGNER, signature.span());

    assert_eq!(result, true);
}
