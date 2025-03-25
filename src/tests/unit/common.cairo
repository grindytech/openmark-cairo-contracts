use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc1155::interface::{IERC1155DispatcherTrait, IERC1155Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::assets::interface::{IERC721MinterDispatcher, IERC721MinterDispatcherTrait};
use openmark::assets::interface::{IERC1155MinterDispatcher, IERC1155MinterDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use openmark::primitives::types::{Stage, StageType};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use starknet::{ContractAddress, contract_address_const};

use openmark::{
    primitives::types::{Order, OrderType}, hasher::interface::{IOffchainMessageHashDispatcher},
    core::OpenMark::{ContractState},
};

pub fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

pub fn ZERO_HASH() -> felt252 {
    0x0
}
pub const OM_OWNER: felt252 = 0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2;
pub const NFT_OWNER: felt252 = 0x03B2d9654644463e040f4264103333179cd9c24E30628fa0B39fab933f58168a;

pub const TEST_PAYMENT: felt252 = 0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
pub const TEST_NFT: felt252 = 0x55FE20463A398171FBDEF9A8DC692E9500D2EBEB8C96D7601D706A253DD8303;

pub const SELLER1: felt252 = 0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca;
pub const SELLER2: felt252 = 0x759ca09377679ecd535a81e83039658bf40959283187c654c5416f439403cf5;
pub const SELLER3: felt252 = 0x411494b501a98abd8262b0da1351e17899a0c4ef23dd2f96fec5ba847310b20;

pub const BUYER1: felt252 = 0x78406570d44f1293762fd99f7e42b034a8a5973542a990a1d1f35c52edf85ef;
pub const BUYER2: felt252 = 0x19661066e96a8b9f06a1d136881ee924dfb6a885239caa5fd3f87a54c6b25c4;
pub const BUYER3: felt252 = 0x4bfad94c8eaa1d5281d9699d0217a69de2f432164f5837b2313c807d3123123;

pub const ROYALTY: u256 = 500; // 5%

pub fn toAddress(addr: felt252) -> ContractAddress {
    return addr.try_into().unwrap();
}

pub fn setup_account(addr: felt252) -> ContractAddress {
    let contract = declare("DualCaseAccountMock").unwrap().contract_class();
    let mut constructor_calldata = array![addr];
    let (contract_address, _) = contract
        .deploy_at(@constructor_calldata, addr.try_into().unwrap())
        .unwrap();
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

pub fn deploy_openmark() -> ContractAddress {
    let contract = declare("OpenMark").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(OM_OWNER);
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

pub fn do_setup_oerc721_at(addr: ContractAddress, owner: ContractAddress) -> ContractAddress {
    let contract = declare("OERC721").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(NFT_NAME());
    constructor_calldata.append_serde(NFT_SYMBOL());
    constructor_calldata.append_serde(NFT_BASE_URI());
    constructor_calldata.append_serde(1000000_u256);
    constructor_calldata.append_serde(ROYALTY);
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

pub fn setup_oerc721_at(addr: ContractAddress) -> ContractAddress {
    return do_setup_oerc721_at(addr, toAddress(NFT_OWNER));
}

pub fn do_create_oerc1155_at(
    addr: ContractAddress,
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    URI: ByteArray,
    maxTokenId: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC1155").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(URI);
    constructor_calldata.append_serde(maxTokenId);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

pub fn do_create_oerc1155(
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    URI: ByteArray,
    maxTokenId: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC1155").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(URI);
    constructor_calldata.append_serde(maxTokenId);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_oerc1155(owner: ContractAddress) -> ContractAddress {
    return do_create_oerc1155(owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, ROYALTY);
}

pub fn create_oerc1155_at(owner: ContractAddress, addr: ContractAddress) -> ContractAddress {
    return do_create_oerc1155_at(
        toAddress(TEST_NFT), owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, ROYALTY,
    );
}

pub fn do_create_buy(
    nft_token: ContractAddress,
    payment_token: ContractAddress,
    seller: ContractAddress,
    buyer: ContractAddress,
) -> (
    Order, // order 
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress // buyer
) {
    let openmark_address = deploy_openmark();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let tokenId = 2;
    let order = Order {
        nftContract: nft_token,
        tokenId: tokenId,
        value: 1,
        payment: payment_token,
        price: 10000,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(nft_token, toAddress(NFT_OWNER));
        let IOM721Dispatcher = IERC721MinterDispatcher { contract_address: nft_token };
        IOM721Dispatcher.mintBatch(seller, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].span());
        start_cheat_caller_address(nft_token, seller);
        ERC721Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 100000);
    let signature = array![
        0x36037f2776f6b844c80a863f09d635ac9464017193a668bede2e82cd8146303,
        0x570bbef96c0334beb61513f923d0ec45751e40baba45829f84fb0dba5202342,
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer)
}

pub fn create_buy() -> (
    Order, // order 
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress // buyer
) {
    let nft_token = setup_oerc721_at(toAddress(TEST_NFT));
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let seller: ContractAddress = toAddress(SELLER1);
    let buyer: ContractAddress = toAddress(BUYER1);
    return do_create_buy(nft_token, payment_token, seller, buyer);
}


pub fn create_buy_with_value() -> (
    Order, // order 
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress // buyer
) {
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let openmark_address = deploy_openmark();
    let seller: ContractAddress = setup_account(SELLER1);

    let nft_token = create_oerc1155_at(toAddress(NFT_OWNER), toAddress(TEST_NFT));
    let buyer: ContractAddress = setup_account(BUYER1);
    let ERC1155Dispatcher = IERC1155Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 2,
        value: 10,
        price: 10000,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        let OERC1155 = IERC1155MinterDispatcher { contract_address: nft_token };
        start_cheat_caller_address(nft_token, toAddress(NFT_OWNER));
        OERC1155
            .mintBatch(seller, [0, 1, 2, 3, 4].span(), [100, 100, 100, 100, 100].span(), [].span());
        start_cheat_caller_address(nft_token, seller);
        ERC1155Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 100_000_000);
    let signature = array![
        0x28bb3abb4bbf4d525445aae869c7d49ff0e51482f860f661929cd7b4e856d88,
        0x40de88ab8ac775f262f1405fa003ae86ee80f84b3061e8a0a4592126d760ecf,
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer)
}

pub fn create_offer() -> (
    Order,
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress // buyer
) {
    let nft_token: ContractAddress = setup_oerc721_at(toAddress(TEST_NFT));
    let payment_token: ContractAddress = setup_balance_at(toAddress(TEST_PAYMENT));

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = toAddress(SELLER1);
    let buyer: ContractAddress = toAddress(BUYER1);
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let token_id = 3_u128;
    let order = Order {
        nftContract: nft_token,
        tokenId: token_id,
        value: 1,
        payment: payment_token,
        price: 10000,
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve nft
    {
        start_cheat_caller_address(nft_token, toAddress(NFT_OWNER));
        let IOM721Dispatcher = IERC721MinterDispatcher { contract_address: nft_token };
        IOM721Dispatcher.mintBatch(seller, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].span());
        start_cheat_caller_address(nft_token, seller);
        ERC721Dispatcher.set_approval_for_all(openmark_address, true);
    }

    // approve eth token
    {
        start_cheat_caller_address(payment_token, buyer);
        ERC20Dispatcher.approve(openmark_address, order.price.into() * order.value.into());
    }

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let signature = array![
        0x5b03e4ae922ddee2576ed284459256bac24fe1111d836f4fad9a606b3182ac8,
        0x202d9ec854b3fe6d602dee84765213b0ae22eeff3edefa6890583e21b594171,
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer)
}

pub fn create_offer_with_value() -> (
    Order,
    Span<felt252>, // signature
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // payment token
    ContractAddress, // seller
    ContractAddress // buyer
) {
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let openmark_address = deploy_openmark();
    let seller: ContractAddress = setup_account(SELLER1);

    let nft_token = create_oerc1155_at(toAddress(NFT_OWNER), toAddress(TEST_NFT));
    let buyer: ContractAddress = setup_account(BUYER1);
    let ERC1155Dispatcher = IERC1155Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let order = Order {
        nftContract: TEST_NFT.try_into().unwrap(),
        tokenId: 3,
        value: 10,
        price: 10000,
        payment: TEST_PAYMENT.try_into().unwrap(),
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve
    {
        start_cheat_caller_address(nft_token, toAddress(NFT_OWNER));
        let OERC1155 = IERC1155MinterDispatcher { contract_address: nft_token };
        OERC1155
            .mintBatch(seller, [0, 1, 2, 3, 4].span(), [100, 100, 100, 100, 100].span(), [].span());
        start_cheat_caller_address(nft_token, seller);
        ERC1155Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 1000_000);
    let signature = array![
        0x7bd2217bbc9bfcf6619df03d9527d2dcb3576edbbecd85f5e92f6580a613c82,
        0x65fb8853f005e92f1cf71c1d203ab1463255ff29f10d0ad2354929c3b665979,
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer)
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
    maxTokenId: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC721").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(baseURI);
    constructor_calldata.append_serde(maxTokenId);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_oerc721(owner: ContractAddress) -> ContractAddress {
    return do_create_oerc721(owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, 0);
}

pub fn create_stage(
    stageType: StageType,
    owner: ContractAddress,
    nft_address: ContractAddress,
    payment_address: ContractAddress,
    rootWhitelist: Option::<felt252>,
    collectionWhitelists: Span<ContractAddress>,
    commission: u32,
    commissionReceiver: ContractAddress,
) -> ContractAddress {
    let stage = Stage {
        stageType: stageType,
        collection: nft_address,
        payment: payment_address,
        price: 10,
        maxAllocation: 10,
        limit: 6,
        startTime: 10,
        endTime: 100,
    };

    let mut contract = declare("StageBatchSelector").unwrap().contract_class();
    if (stageType == StageType::Randomness) {
        contract = declare("StageVRF").unwrap().contract_class();
    } else if (stageType == StageType::Selector) {
        contract = declare("StageSelector").unwrap().contract_class();
    }
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(stage);
    constructor_calldata.append_serde(rootWhitelist);
    constructor_calldata.append_serde(collectionWhitelists);
    constructor_calldata.append_serde(commission);
    constructor_calldata.append_serde(commissionReceiver);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}
