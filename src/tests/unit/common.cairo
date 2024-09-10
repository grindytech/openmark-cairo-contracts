use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::token::interface::IOpenMarkNFTDispatcherTrait;
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address,};

use starknet::{ContractAddress, contract_address_const};

use openmark::{
    primitives::types::{Order, Bid, OrderType, SignedBid},
    hasher::interface::{IOffchainMessageHashDispatcher}, core::OpenMark::{ContractState},
    token::interface::{IOpenMarkNFTDispatcher}
};

pub fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

pub const TEST_PAYMENT: felt252 = 0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
pub const TEST_NFT: felt252 = 0x55FE20463A398171FBDEF9A8DC692E9500D2EBEB8C96D7601D706A253DD8303;

pub const SELLER1: felt252 = 0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca;
pub const SELLER2: felt252 = 0x759ca09377679ecd535a81e83039658bf40959283187c654c5416f439403cf5;
pub const SELLER3: felt252 = 0x411494b501a98abd8262b0da1351e17899a0c4ef23dd2f96fec5ba847310b20;

pub const BUYER1: felt252 = 0x78406570d44f1293762fd99f7e42b034a8a5973542a990a1d1f35c52edf85ef;
pub const BUYER2: felt252 = 0x19661066e96a8b9f06a1d136881ee924dfb6a885239caa5fd3f87a54c6b25c4;
pub const BUYER3: felt252 = 0x4bfad94c8eaa1d5281d9699d0217a69de2f432164f5837b2313c807d3123123;

pub fn OPENMARK_NFT_NAME() -> ByteArray {
    "OpenMark NFT"
}

pub fn OPENMARK_NFT_SYMBOL() -> ByteArray {
    "OM"
}

pub fn OPENMARK_NFT_BASE_URI() -> ByteArray {
    "https://nft-api.openmark.io/"
}

pub fn deploy_openmark() -> ContractAddress {
    let contract = declare("OpenMark").unwrap();
    let payment_token = deploy_erc20_at(TEST_PAYMENT.try_into().unwrap());

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(payment_token);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

pub fn create_mock_hasher() -> IOffchainMessageHashDispatcher {
    let contract = declare("HasherMock").unwrap();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let hasher_contract = IOffchainMessageHashDispatcher { contract_address };
    hasher_contract
}

pub fn deploy_mock_account() -> ContractAddress {
    let contract = declare("AccountMock").unwrap();
    let mut constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn deploy_erc20() -> ContractAddress {
    let contract = declare("OpenMarkCoinMock").unwrap();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = BUYER1.try_into().unwrap();

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn deploy_erc20_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkCoinMock").unwrap();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = BUYER1.try_into().unwrap();

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

pub fn do_create_nft(
    owner: ContractAddress, name: ByteArray, symbol: ByteArray, base_uri: ByteArray
) -> ContractAddress {
    let contract = declare("OpenMarkNFTMock").unwrap();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(base_uri);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

pub fn create_openmark_nft() -> ContractAddress {
    do_create_nft(
        SELLER1.try_into().unwrap(),
        OPENMARK_NFT_NAME(),
        OPENMARK_NFT_SYMBOL(),
        OPENMARK_NFT_BASE_URI()
    )
}

pub fn create_openmark_nft_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkNFTMock").unwrap();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(OPENMARK_NFT_NAME());
    constructor_calldata.append_serde(OPENMARK_NFT_SYMBOL());
    constructor_calldata.append_serde(OPENMARK_NFT_BASE_URI());
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
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
    let nft_token: ContractAddress = create_openmark_nft_at(TEST_NFT.try_into().unwrap());
    let payment_token: ContractAddress = TEST_PAYMENT.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = SELLER1.try_into().unwrap();
    let buyer: ContractAddress = BUYER1.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let order = Order {
        nftContract: nft_token,
        tokenId: 2,
        payment: payment_token,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(nft_token, seller);

        let IOM721Dispatcher = IOpenMarkNFTDispatcher { contract_address: nft_token };
        IOM721Dispatcher.safe_batch_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, 2);
    }

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 3);
    let signature = array![
        0x5ef9810b7349fc322d2d58c30a73712a63439ca1557b1d4643abc8d570e9dd7,
        0x65f73bc60f64edbfc923019bbbf9f4e79f941d9585656333cdd615b2cde6b85
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
    let nft_token: ContractAddress = create_openmark_nft_at(TEST_NFT.try_into().unwrap());
    let payment_token: ContractAddress = TEST_PAYMENT.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = SELLER1.try_into().unwrap();
    let buyer: ContractAddress = BUYER1.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let price = 3_u128;
    let token_id = 3_u128;
    let order = Order {
        nftContract: nft_token,
        tokenId: token_id,
        payment: payment_token,
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve nft
    {
        start_cheat_caller_address(nft_token, seller);

        let IOM721Dispatcher = IOpenMarkNFTDispatcher { contract_address: nft_token };
        IOM721Dispatcher.safe_batch_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, token_id.into());
    }

    // approve eth token
    {
        start_cheat_caller_address(payment_token, buyer);
        ERC20Dispatcher.approve(seller, price.into() + 1);
        ERC20Dispatcher.approve(openmark_address, price.into() + 1);
    }

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let signature = array![
        0x72a7674dee45709736bae2fa2043607b255fad13cfa1b5af97784c41a7501fd,
        0x550703e0430d53fa3aed27b409d489048c2fc0a8a9a30c64ff9d5a6d858c7c
    ];

    (order, signature.span(), openmark_address, nft_token, payment_token, seller, buyer,)
}

pub fn create_bids() -> (
    Span<SignedBid>, // signed bids
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // token payment address
    ContractAddress, // seller
    Span<ContractAddress>, // buyers
    Span<u128>, // sell nft token ids
) {
    let nft_token: ContractAddress = create_openmark_nft_at(TEST_NFT.try_into().unwrap());
    let payment_token: ContractAddress = TEST_PAYMENT.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = SELLER1.try_into().unwrap();

    let buyer1: ContractAddress = BUYER1.try_into().unwrap();
    let buyer2: ContractAddress = BUYER2.try_into().unwrap();
    let buyer3: ContractAddress = BUYER3.try_into().unwrap();

    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let unitPrice = 3_u128;
    let total_amount = 10;
    let bid1 = Bid {
        nftContract: nft_token, amount: 1, payment: payment_token, unitPrice, salt: 4, expiry: 5,
    };
    let bid2 = Bid {
        nftContract: nft_token, amount: 2, payment: payment_token, unitPrice, salt: 4, expiry: 5,
    };
    let bid3 = Bid {
        nftContract: nft_token, amount: 3, payment: payment_token, unitPrice, salt: 4, expiry: 5,
    };

    // create and approve nfts
    {
        let IOM721Dispatcher = IOpenMarkNFTDispatcher { contract_address: nft_token };
        start_cheat_caller_address(nft_token, seller);
        IOM721Dispatcher.safe_batch_mint(seller, total_amount);

        let mut token_id = 0_u256;
        while token_id < total_amount {
            ERC721Dispatcher.approve(openmark_address, token_id);
            token_id += 1;
        }
    }

    // faucet and approve eth token
    {
        let approve_amount = 1000000_u256;
        start_cheat_caller_address(payment_token, buyer1);
        ERC20Dispatcher.transfer(buyer2, approve_amount);
        ERC20Dispatcher.transfer(buyer3, approve_amount);

        start_cheat_caller_address(payment_token, buyer1);
        ERC20Dispatcher.approve(openmark_address, approve_amount);

        start_cheat_caller_address(payment_token, buyer2);
        ERC20Dispatcher.approve(openmark_address, approve_amount);

        start_cheat_caller_address(payment_token, buyer3);
        ERC20Dispatcher.approve(openmark_address, approve_amount);
    }

    let signed_bids = array![
        SignedBid {
            bidder: buyer1, bid: bid1, signature: [
                0x603d39c370bedfe3f08c2f9f86f23616ebe0d6294ed1edbef92096ff378a7e9,
                0x5d7625a6d3ac77231dd153c17c4439cf64ba217efabec9263e978872dfc29c8
            ].span()
        },
        SignedBid {
            bidder: buyer2,
            bid: bid2,
            signature: array![
                0x3180b2cb0aeed1643ac7efa5d56e29e793b7a396f4ff6b3f4fe588208211c64,
                0x5615fce3720669df0e3acdf91d7c93122074bdfa535bde0b383ede0d546f8e9
            ]
                .span()
        },
        SignedBid {
            bidder: buyer3,
            bid: bid3,
            signature: array![
                0x3a57b5f8f5d87b5326a078593c3414bb4d7b7282b0d4550cb09a2714d4774f7,
                0x1e2f9728548d1203e0d0fc07dcb9092230729aabc3fed319f5452b7818736bb
            ]
                .span()
        },
    ];

    let tokenIds = array![0, 1, 2, 3, 4, 5].span();

    (
        signed_bids.span(),
        openmark_address,
        nft_token,
        payment_token,
        seller,
        array![buyer1, buyer2, buyer3].span(),
        tokenIds
    )
}

pub fn get_contract_state_for_testing() -> ContractState {
    let mut state = openmark::core::OpenMark::contract_state_for_testing();
    state.maxBidNFTs.write(10);

    state
}
