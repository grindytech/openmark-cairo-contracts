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
    let message_hash = 0x4d5c7bf7d624d7ade7f8d4c73092ebcb9287e2be556ef15f65116dc94421bd1;
    let order = Order {
        nftContract: 1.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };
    let signer = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

    start_cheat_caller_address(contract_address, signer.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_order_hash(order, signer);

    assert_eq!(result, message_hash);
}

#[test]
#[available_gas(2000000)]
fn get_bid_hash_works() {
    let contract_address = deploy_mock_hasher();
    // This value was computed using StarknetJS
    let message_hash = 0x494528c3fea34a10288c602ca2d1453c780dda745d9f5873b8f96ea7c3283db;
    let bid = Bid {
        nftContract: 1.try_into().unwrap(), amount: 2, unitPrice: 3, salt: 4, expiry: 5,
    };
    let signer = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

    start_cheat_caller_address(contract_address, signer.try_into().unwrap());
    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.get_bid_hash(bid, signer);

    assert_eq!(result, message_hash);
}

#[test]
#[available_gas(2000000)]
fn verify_order_works() {
    let contract_address = deploy_mock_hasher();

    let order = Order {
        nftContract: 1.try_into().unwrap(),
        tokenId: 2,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };
    let signer = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

    let mut signature = array![
        0x7d22529d850174cd51eca7e156397cce6518c7bc82343758382e16c5fe9fe55,
        0x4aa8aab803bc9fe0f6579367ef034f8a98d2ccd1617eb0b48ece03819ac2e2
    ];

    start_cheat_caller_address(contract_address, signer.try_into().unwrap());

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verifyOrder(order, signer, signature.span());

    assert_eq!(result, true);
}

#[test]
#[available_gas(2000000)]
fn verify_bid_works() {
    let contract_address = deploy_mock_hasher();

    let bid = Bid {
        nftContract: 1.try_into().unwrap(), amount: 2, unitPrice: 3, salt: 4, expiry: 5,
    };

    let signer = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

    let mut signature = array![
        0x56d15925e9f7dd3eefbaed9f3eb3e7a15cf1614e05ffb4efa913becb2ecd0ae,
        0x53ea87fce30d0f4794ff9fa817dde7a8c5e452a2a755ce4791c81a9891cb9f
    ];

    let dispatcher = IOffchainMessageHashDispatcher { contract_address };

    let result = dispatcher.verifyBid(bid, signer, signature.span());

    assert_eq!(result, true);
}
