use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::interface::IOM721TokenDispatcherTrait;
use openzeppelin::tests::utils::constants::OWNER;
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address
};

use starknet::{
    ContractAddress, contract_address_const, get_tx_info, get_caller_address,
};

use openmark::{
    primitives::{Order, Bid, OrderType},
    interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOM721TokenDispatcher
    },
};

const TEST_ETH_ADDRESS: felt252 = 0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
const TEST_ERC721_ADDRESS: felt252 =
    0x52D3AA5AF7D5A5D024F99EF80645C32B0E94C9CC4645CDA09A36BE2696257AA;
const TEST_SELLER: felt252 = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;
const TEST_BUYER: felt252 = 0x913b4e904ab75554db59b64e1d26116d1ba1c033ce57519b53e35d374ef2dd;

fn deploy_openmark() -> ContractAddress {
    let contract = declare("OpenMark").unwrap();
    let eth_address = deploy_erc20_at(TEST_ETH_ADDRESS.try_into().unwrap());

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(OWNER());
    constructor_calldata.append_serde(eth_address);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}


fn deploy_erc20() -> ContractAddress {
    let contract = declare("OpenMarkCoin").unwrap();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = TEST_BUYER.try_into().unwrap();

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_erc20_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkCoin").unwrap();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = TEST_BUYER.try_into().unwrap();

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

fn deploy_erc721() -> ContractAddress {
    let contract = declare("OpenMarkNFT").unwrap();

    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_erc721_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkNFT").unwrap();

    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

#[test]
#[available_gas(2000000)]
fn get_order_hash_works() {
    let contract_address = deploy_openmark();
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
    let contract_address = deploy_openmark();
    // This value was computed using StarknetJS
    let message_hash = 0x494528c3fea34a10288c602ca2d1453c780dda745d9f5873b8f96ea7c3283db;
    let bid = Bid {
        nftContract: 1.try_into().unwrap(),
        amount: 2,
        unitPrice: 3,
        salt: 4,
        expiry: 5,
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
    let contract_address = deploy_openmark();

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

    let dispatcher = IOpenMarkDispatcher { contract_address };

    let result = dispatcher.verifyOrder(order, signer, signature.span());

    assert_eq!(result, true);
}

#[test]
#[available_gas(2000000)]
fn buy_works() {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());
    let eth_address: ContractAddress = TEST_ETH_ADDRESS.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();
    let buyer: ContractAddress = TEST_BUYER.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: erc721_address };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: eth_address };

    let price = 3_u128;
    let order = Order {
        nftContract: erc721_address,
        tokenId: 2,
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(erc721_address, seller);

        let IOM721Dispatcher = IOM721TokenDispatcher { contract_address: erc721_address };
        IOM721Dispatcher.safe_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, 2);
    }

    // buy and verify
    {
        start_cheat_caller_address(openmark_address, buyer);
        start_cheat_caller_address(eth_address, buyer);

        ERC20Dispatcher.approve(openmark_address, 3);

        let mut signature = array![
            0x5228d8ebab110b3038c328892e8293c49ef8777f02de0e094c1a902e91e0271,
            0x72ac0a9ad3fd5ad9143a720148d174e724aa752dfedc6e4dce767b82cbbd913
        ];
        let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

        let buyer_before_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_before_balance = ERC20Dispatcher.balance_of(seller);

        OpenMarkDispatcher.buy(seller, order, signature.span());
        let buyer_after_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_after_balance = ERC20Dispatcher.balance_of(seller);

        assert_eq!(ERC721Dispatcher.owner_of(2), buyer);
        assert_eq!(buyer_after_balance, buyer_before_balance - price.into());
        assert_eq!(seller_after_balance, seller_before_balance + price.into());
    }
}


#[test]
#[available_gas(2000000)]
fn accept_offer_works() {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());
    let eth_address: ContractAddress = TEST_ETH_ADDRESS.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();
    let buyer: ContractAddress = TEST_BUYER.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: erc721_address };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: eth_address };

    let price = 3_u128;
    let token_id = 3_u128;
    let order = Order {
        nftContract: erc721_address,
        tokenId: token_id,
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve nft
    {
        start_cheat_caller_address(erc721_address, seller);

        let IOM721Dispatcher = IOM721TokenDispatcher { contract_address: erc721_address };
        IOM721Dispatcher.safe_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, token_id.into());
    }

    // approve eth token
    {
        start_cheat_caller_address(eth_address, buyer);
        ERC20Dispatcher.approve(seller, price.into() + 1);
        ERC20Dispatcher.approve(openmark_address, price.into() + 1);
    }

    // buy and verify
    {
        start_cheat_caller_address(openmark_address, seller);
        start_cheat_caller_address(eth_address, openmark_address);

        let mut signature = array![
            0x431ba689471acd01b7642947c74f4048beb2232ab214f85c667d9328c5067c0,
            0x57a29a567e6240506f8d03682f4ac7d970afc3f228da7a96b942306d8b966f1
        ];
        let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

        let buyer_before_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_before_balance = ERC20Dispatcher.balance_of(seller);

        OpenMarkDispatcher.acceptOffer(buyer, order, signature.span());

        let buyer_after_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_after_balance = ERC20Dispatcher.balance_of(seller);

        assert_eq!(ERC721Dispatcher.owner_of(token_id.into()), buyer);
        assert_eq!(buyer_after_balance, buyer_before_balance - price.into());
        assert_eq!(seller_after_balance, seller_before_balance + price.into());
    }
}


#[test]
#[available_gas(2000000)]
fn cancel_order_works() {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();

    let order = Order {
        nftContract: erc721_address,
        tokenId: 2,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    {
        start_cheat_caller_address(openmark_address, seller);

        let mut signature = array![
            0x5228d8ebab110b3038c328892e8293c49ef8777f02de0e094c1a902e91e0271,
            0x72ac0a9ad3fd5ad9143a720148d174e724aa752dfedc6e4dce767b82cbbd913
        ];
        let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };
        OpenMarkDispatcher.cancelOrder(order, signature.span());

        let usedOrderSignatures = load(
            openmark_address,
            map_entry_address(selector!("usedOrderSignatures"), signature.span(),),
            1,
        );

        assert_eq!( *usedOrderSignatures.at(0), true.into());
    }
}
