use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::token::interface::IOpenMarkNFTDispatcherTrait;
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy,
    start_cheat_block_timestamp
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::types::{Order, Bid, OrderType, SignedBid},
    core::interface::{
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOpenMarkProvider,
        IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait
    },
    hasher::interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash
    },
    token::interface::{IOpenMarkNFTDispatcher}, core::OpenMark::Event as OpenMarkEvent,
    core::OpenMark::{maxBidsContractMemberStateTrait, ContractState},
    core::events::{OrderFilled, OrderCancelled, BidCancelled}, core::errors as Errors,
};

pub fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

pub const TEST_ETH_ADDRESS: felt252 =
    0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
pub const TEST_ERC721_ADDRESS: felt252 =
    0x55FE20463A398171FBDEF9A8DC692E9500D2EBEB8C96D7601D706A253DD8303;
pub const TEST_SELLER: felt252 = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

pub const TEST_BUYER1: felt252 = 0x913b4e904ab75554db59b64e1d26116d1ba1c033ce57519b53e35d374ef2dd;
pub const TEST_BUYER2: felt252 = 0x30f0a5f5311ad0fa15cf1f8c22677c366ad0fd66d9e5ca588957ada394430f8;
pub const TEST_BUYER3: felt252 = 0x4136107a5d3c1a6cd4c28693ea6a0e5bb9ffa648467629a9900183cf623c40a;

pub fn SELL_SIGNATURES() -> Span<felt252> {
    array![
        0xe75494836b56da6d28f2c18ee2716cb89ce8438b4c9d0127390feb12433f3d,
        0xfa8533c614eac3b508e14f5cd86ea583cb7e4842938574559e8927696c16fb
    ]
        .span()
}
pub fn OFFER_SIGNATURES() -> Span<felt252> {
    array![
        0xce3a19678534f8e7420bbe3c4613a0a716eff23925de684b5fafaa00e754c9,
        0x3d5429d1e2d1cb26392c87b385c94741f2d80aba24525e7411a319800e77f07
    ]
        .span()
}
pub fn BID_SIGNATURES() -> (Span<felt252>, Span<felt252>, Span<felt252>) {
    (
        array![
            0x4ea67a94ac0e95d87bfe2a39cb9728443a56850ced121afbcf0b47877f2edde,
            0x7f0c4be2712170650643257b183d36cc93e13201788e3c45ba946a8622d97cb
        ]
            .span(),
        array![
            0x7d36cfee3552e78c1a60afe10366c66142eabcd30c28e3200a12fee3ad557ba,
            0x1197015e853fd8f56e7ad8dda624163e6fd862770c4bcf295aad94414557570
        ]
            .span(),
        array![
            0x53cc0434c9c75305d06e1be89fd92260e9b920140b230fe25505d10f1df92d0,
            0x6524f145d25a95c1de68bb0fc64351a7e86b8ac06850131c9dc632ec12088
        ]
            .span(),
    )
}

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
    let eth_address = deploy_erc20_at(TEST_ETH_ADDRESS.try_into().unwrap());

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(TEST_SELLER);
    constructor_calldata.append_serde(eth_address);

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

pub fn deploy_erc20() -> ContractAddress {
    let contract = declare("OpenMarkCoin").unwrap();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = TEST_BUYER1.try_into().unwrap();

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn deploy_erc20_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkCoin").unwrap();
    let mut constructor_calldata = array![];
    let initial_supply = 1000000000000000000000000000_u256;
    let recipient: ContractAddress = TEST_BUYER1.try_into().unwrap();

    constructor_calldata.append_serde(initial_supply);
    constructor_calldata.append_serde(recipient);
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();
    contract_address
}

pub fn create_openmark_nft() -> ContractAddress {
    let contract = declare("OpenMarkNFT").unwrap();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(TEST_SELLER);
    constructor_calldata.append_serde(OPENMARK_NFT_NAME());
    constructor_calldata.append_serde(OPENMARK_NFT_SYMBOL());
    constructor_calldata.append_serde(OPENMARK_NFT_BASE_URI());

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

pub fn create_openmark_nft_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkNFT").unwrap();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(TEST_SELLER);
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
    let erc721_address: ContractAddress = create_openmark_nft_at(
        TEST_ERC721_ADDRESS.try_into().unwrap()
    );
    let eth_address: ContractAddress = TEST_ETH_ADDRESS.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();
    let buyer: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: erc721_address };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: eth_address };

    let order = Order {
        nftContract: erc721_address,
        tokenId: 2,
        payment: eth_address,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(erc721_address, seller);

        let IOM721Dispatcher = IOpenMarkNFTDispatcher { contract_address: erc721_address };
        IOM721Dispatcher.safe_batch_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, 2);
    }

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    ERC20Dispatcher.approve(openmark_address, 3);

    (order, SELL_SIGNATURES(), openmark_address, erc721_address, eth_address, seller, buyer,)
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
    let erc721_address: ContractAddress = create_openmark_nft_at(
        TEST_ERC721_ADDRESS.try_into().unwrap()
    );
    let eth_address: ContractAddress = TEST_ETH_ADDRESS.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();
    let buyer: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: erc721_address };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: eth_address };

    let price = 3_u128;
    let token_id = 3_u128;
    let order = Order {
        nftContract: erc721_address,
        tokenId: token_id,
        payment: eth_address,
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve nft
    {
        start_cheat_caller_address(erc721_address, seller);

        let IOM721Dispatcher = IOpenMarkNFTDispatcher { contract_address: erc721_address };
        IOM721Dispatcher.safe_batch_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, token_id.into());
    }

    // approve eth token
    {
        start_cheat_caller_address(eth_address, buyer);
        ERC20Dispatcher.approve(seller, price.into() + 1);
        ERC20Dispatcher.approve(openmark_address, price.into() + 1);
    }

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    (order, OFFER_SIGNATURES(), openmark_address, erc721_address, eth_address, seller, buyer,)
}

pub fn create_bids() -> (
    Span<SignedBid>, // signed bids
    ContractAddress, // openmark address
    ContractAddress, // nft address
    ContractAddress, // token payment address
    ContractAddress, // seller
    Span<ContractAddress>, // buyers
    Span<u128>, // sell nft token ids
    u128 // asking price
) {
    let erc721_address: ContractAddress = create_openmark_nft_at(
        TEST_ERC721_ADDRESS.try_into().unwrap()
    );
    let eth_address: ContractAddress = TEST_ETH_ADDRESS.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();

    let buyer1: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let buyer2: ContractAddress = TEST_BUYER2.try_into().unwrap();
    let buyer3: ContractAddress = TEST_BUYER3.try_into().unwrap();

    let ERC721Dispatcher = IERC721Dispatcher { contract_address: erc721_address };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: eth_address };

    let unitPrice = 3_u128;
    let total_amount = 10;
    let bid1 = Bid {
        nftContract: erc721_address, amount: 1, payment: eth_address, unitPrice, salt: 4, expiry: 5,
    };
    let bid2 = Bid {
        nftContract: erc721_address, amount: 2, payment: eth_address, unitPrice, salt: 4, expiry: 5,
    };
    let bid3 = Bid {
        nftContract: erc721_address, amount: 3, payment: eth_address, unitPrice, salt: 4, expiry: 5,
    };

    // create and approve nfts
    {
        let IOM721Dispatcher = IOpenMarkNFTDispatcher { contract_address: erc721_address };
        start_cheat_caller_address(erc721_address, seller);
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
        start_cheat_caller_address(eth_address, buyer1);
        ERC20Dispatcher.transfer(buyer2, approve_amount);
        ERC20Dispatcher.transfer(buyer3, approve_amount);

        start_cheat_caller_address(eth_address, buyer1);
        ERC20Dispatcher.approve(openmark_address, approve_amount);

        start_cheat_caller_address(eth_address, buyer2);
        ERC20Dispatcher.approve(openmark_address, approve_amount);

        start_cheat_caller_address(eth_address, buyer3);
        ERC20Dispatcher.approve(openmark_address, approve_amount);
    }

    let (sig1, sig2, sig3) = BID_SIGNATURES();
    let signed_bids = array![
        SignedBid { bidder: buyer1, bid: bid1, signature: sig1 },
        SignedBid { bidder: buyer2, bid: bid2, signature: sig2 },
        SignedBid { bidder: buyer3, bid: bid3, signature: sig3 },
    ];

    let tokenIds = array![0, 1, 2, 3, 4, 5].span();

    (
        signed_bids.span(),
        openmark_address,
        erc721_address,
        eth_address,
        seller,
        array![buyer1, buyer2, buyer3].span(),
        tokenIds,
        unitPrice
    )
}

pub fn get_contract_state_for_testing() -> ContractState {
    let mut state = openmark::core::OpenMark::contract_state_for_testing();
    state.maxBids.write(10);

    state
}
