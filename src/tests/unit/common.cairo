use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc1155::interface::{IERC1155DispatcherTrait, IERC1155Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::assets::interface::{IERC721MinterDispatcher, IERC721MinterDispatcherTrait};
use openmark::assets::interface::{IERC1155MinterDispatcher, IERC1155MinterDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, get_class_hash
};

use starknet::{ContractAddress, contract_address_const};

use openmark::{
    primitives::types::{Order, OrderType}, hasher::interface::{IOffchainMessageHashDispatcher},
    core::OpenMark::{ContractState}
};
use openmark::factory::interface::{ILaunchpadFactoryDispatcher,};

pub fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

pub fn ZERO_HASH() -> felt252 {
    0x0
}

pub const TEST_PAYMENT: felt252 = 0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
pub const TEST_NFT: felt252 = 0x55FE20463A398171FBDEF9A8DC692E9500D2EBEB8C96D7601D706A253DD8303;

pub const SELLER1: felt252 = 0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca;
pub const SELLER2: felt252 = 0x759ca09377679ecd535a81e83039658bf40959283187c654c5416f439403cf5;
pub const SELLER3: felt252 = 0x411494b501a98abd8262b0da1351e17899a0c4ef23dd2f96fec5ba847310b20;

pub const BUYER1: felt252 = 0x78406570d44f1293762fd99f7e42b034a8a5973542a990a1d1f35c52edf85ef;
pub const BUYER2: felt252 = 0x19661066e96a8b9f06a1d136881ee924dfb6a885239caa5fd3f87a54c6b25c4;
pub const BUYER3: felt252 = 0x4bfad94c8eaa1d5281d9699d0217a69de2f432164f5837b2313c807d3123123;

pub fn toAddress(addr: felt252) -> ContractAddress {
    return addr.try_into().unwrap();
}

pub fn setup_account(addr: felt252) -> ContractAddress {
    let contract = declare("DualCaseAccountMock").unwrap().contract_class();
    let mut constructor_calldata = array![addr];
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr.try_into().unwrap()).unwrap();
    contract_address
}

pub fn NFT_NAME() -> ByteArray {
    "OpenMark NFT"
}

pub fn NFT_SYMBOL() -> ByteArray {
    "OM"
}

pub fn NFT_BASE_URI() -> ByteArray {
    "https://nft-api.openmark.io/"
}

pub fn deploy_openmark(payment_token: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMark").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(payment_token);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_mock_hasher() -> IOffchainMessageHashDispatcher {
    let contract = declare("HasherMock").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let hasher_contract = IOffchainMessageHashDispatcher { contract_address };
    hasher_contract
}

pub fn deploy_mock_account() -> ContractAddress {
    let contract = declare("AccountMock").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_erc20(owner: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkCoinMock").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(owner);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn setup_balance_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkCoinMock").unwrap().contract_class();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = toAddress(BUYER1);

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();

    let erc20_dispatcher = IERC20Dispatcher { contract_address };
    start_cheat_caller_address(contract_address, toAddress(BUYER1));

    erc20_dispatcher.transfer(toAddress(BUYER1), 10000000000000000);
    erc20_dispatcher.transfer(toAddress(BUYER2), 10000000000000000);

    erc20_dispatcher.transfer(toAddress(SELLER1), 10000000000000000);
    erc20_dispatcher.transfer(toAddress(SELLER2), 10000000000000000);
    erc20_dispatcher.transfer(toAddress(SELLER3), 10000000000000000);
    contract_address
}

pub fn create_test_oerc721() -> ContractAddress {
    return setup_oerc721_at(toAddress(TEST_NFT));
}

pub fn setup_oerc721_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OERC721").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(NFT_NAME());
    constructor_calldata.append_serde(NFT_SYMBOL());
    constructor_calldata.append_serde(NFT_BASE_URI());
    constructor_calldata.append_serde(1000000_u256);
    constructor_calldata.append_serde(1000_u256);
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();

    contract_address
}

pub fn do_create_oerc1155(
    addr: ContractAddress,
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    URI: ByteArray,
    totalSupply: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC1155").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(URI);
    constructor_calldata.append_serde(totalSupply);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

pub fn create_oerc1155(owner: ContractAddress,) -> ContractAddress {
    return do_create_oerc1155(
        toAddress(TEST_NFT), owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, 0
    );
}

pub fn create_buy() -> (
    Order, // order 
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress, // buyer
) {
    let nft_token = setup_oerc721_at(toAddress(TEST_NFT));
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let openmark_address = deploy_openmark(payment_token);
    let seller: ContractAddress = toAddress(SELLER1);
    let buyer: ContractAddress = toAddress(BUYER1);
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let tokenId = 2;
    let order = Order {
        nftContract: nft_token,
        tokenId: tokenId,
        value: 1,
        payment: payment_token,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(nft_token, seller);
        let IOM721Dispatcher = IERC721MinterDispatcher { contract_address: nft_token };
        IOM721Dispatcher.mintBatch(seller, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].span());
        ERC721Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 100000);
    let signature = array![
        0x3358bee5f4f2357907a7e5f0f71df53813264ef62dc99f2954a661d8c60085e,
        0x3c8c95d75ec7f9e13f70ef2b74ce9e45c2a66ff390b9732c002319b5eb19bfb
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer,)
}


pub fn create_buy_with_value() -> (
    Order, // order 
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress, // buyer
) {
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let openmark_address = deploy_openmark(payment_token);
    let seller: ContractAddress = setup_account(SELLER1);

    let nft_token = create_oerc1155(seller);
    let buyer: ContractAddress = setup_account(BUYER1);
    let ERC1155Dispatcher = IERC1155Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };
  
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

   
    // create and approve
    {
        let OERC1155 = IERC1155MinterDispatcher { contract_address: nft_token };
        start_cheat_caller_address(nft_token, seller);
        OERC1155
            .mintBatch(seller, [0, 1, 2, 3, 4].span(), [100, 100, 100, 100, 100].span(), [].span());
        ERC1155Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 1000_000);
    let signature = array![
        0x483f9a732042df50d80d7dd1363894bc924a7c3181027a611fdd90085730dc3,
        0x25fa6058f6c6859bcf604a37b3515485ad0937cab485715c81f36f4fd5e3f6a
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer,)
}

pub fn create_offer() -> (
    Order,
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress, // buyer
) {
    let nft_token: ContractAddress = setup_oerc721_at(toAddress(TEST_NFT));
    let payment_token: ContractAddress = setup_balance_at(toAddress(TEST_PAYMENT));

    let openmark_address = deploy_openmark(payment_token);
    let seller: ContractAddress = toAddress(SELLER1);
    let buyer: ContractAddress = toAddress(BUYER1);
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let price = 3_u128;
    let token_id = 3_u128;
    let order = Order {
        nftContract: nft_token,
        tokenId: token_id,
        value: 1,
        payment: payment_token,
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve nft
    {
        start_cheat_caller_address(nft_token, seller);
        let IOM721Dispatcher = IERC721MinterDispatcher { contract_address: nft_token };
        IOM721Dispatcher.mintBatch(seller, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].span());
        ERC721Dispatcher.approve(openmark_address, token_id.into());
    }

    // approve eth token
    {
        start_cheat_caller_address(payment_token, buyer);
        // ERC20Dispatcher.approve(seller, price.into() + 1);
        ERC20Dispatcher.approve(openmark_address, price.into() + 1);
    }

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let signature = array![
        0x6fafd2ac1e7f1f9aaa9036084b908d3dd43d81ce464ea15e283ba020694401e,
        0x7b2e324f04765d33d3352b3281dcb3d37d1a6e7403dee12dd4d208de2aba95d
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer,)
}

pub fn create_offer_with_value() -> (
    Order,
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress, // buyer
) {
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let openmark_address = deploy_openmark(payment_token);
    let seller: ContractAddress = setup_account(SELLER1);

    let nft_token = create_oerc1155(seller);
    let buyer: ContractAddress = setup_account(BUYER1);
    let ERC1155Dispatcher = IERC1155Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };
  
    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 3,
        value: 10,
        price: 3,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

   
    // create and approve
    {
        let OERC1155 = IERC1155MinterDispatcher { contract_address: nft_token };
        start_cheat_caller_address(nft_token, seller);
        OERC1155
            .mintBatch(seller, [0, 1, 2, 3, 4].span(), [100, 100, 100, 100, 100].span(), [].span());
        ERC1155Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 1000_000);
    let signature = array![
        0x4a0c93b2c8c9ac9ffc60c90ab88fcd6207ec568714c49cca4bc90c8e67b677e,
        0x5f2f25bae627735ca9628431938571a763804e233dc245b64144d5a37a9a5d0
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer,)
}

fn create_launchpad_template() -> ContractAddress {
    let contract = declare("Launchpad").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(toAddress(SELLER1));
    constructor_calldata.append_serde(NFT_BASE_URI());
    constructor_calldata.append_serde(0_u128);
    constructor_calldata.append_serde(toAddress(TEST_PAYMENT));
    constructor_calldata.append_serde(toAddress(TEST_PAYMENT));

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    return contract_address;
}

pub fn create_launchpad_factory(
    owner: ContractAddress,
    lockAmount: u128,
    lockTokenAddress: ContractAddress,
    paymentTokens: Span<ContractAddress>
) -> (ContractAddress, ILaunchpadFactoryDispatcher) {
    let launchpad = create_launchpad_template();
    let launchpad_classhash = get_class_hash(launchpad);

    let contract = declare("LaunchpadFactory").unwrap().contract_class();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(lockAmount);
    constructor_calldata.append_serde(lockTokenAddress);
    constructor_calldata.append_serde(paymentTokens);
    constructor_calldata.append_serde(launchpad_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, ILaunchpadFactoryDispatcher { contract_address })
}

pub fn get_contract_state_for_testing() -> ContractState {
    let mut state = openmark::core::OpenMark::contract_state_for_testing();
    state
}

pub fn do_create_oerc721(
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    baseURI: ByteArray,
    totalSupply: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC721").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(baseURI);
    constructor_calldata.append_serde(totalSupply);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_oerc721(owner: ContractAddress,) -> ContractAddress {
    return do_create_oerc721(owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, 0);
}