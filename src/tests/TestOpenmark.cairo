use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use openmark::interface::IOM721TokenDispatcherTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use snforge_std::signature::SignerTrait;
use openzeppelin::tests::utils::constants::OWNER;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address};
use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address};
use openmark::{
    primitives::{Order, OrderType},
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
fn get_message_hash_works() {
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

    let result = dispatcher.get_message_hash(order, signer);

    assert_eq!(result, message_hash,);
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
    let ERC20Dispatcher = IERC20CamelDispatcher { contract_address: eth_address };

    let price = 3_u128;
    let order = Order {
        nftContract: erc721_address,
        tokenId: 2,
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create setPrice
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

        let buyer_before_balance = ERC20Dispatcher.balanceOf(buyer);
        let seller_before_balance = ERC20Dispatcher.balanceOf(seller);

        OpenMarkDispatcher.buy(seller, order, signature.span());
        let buyer_after_balance = ERC20Dispatcher.balanceOf(buyer);
        let seller_after_balance = ERC20Dispatcher.balanceOf(seller);

        assert_eq!(ERC721Dispatcher.owner_of(2), buyer);
        assert_ne!(buyer_before_balance, buyer_after_balance - price.into());
        assert_ne!(seller_before_balance, seller_after_balance + price.into());
    }
}

