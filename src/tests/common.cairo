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
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy,
    start_cheat_block_timestamp
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::{Order, Bid, OrderType, SignedBid},
    interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOM721TokenDispatcher
    },
    openmark::OpenMark::Event as OpenMarkEvent,
    openmark::OpenMark::{maxBidsContractMemberStateTrait, ContractState},
    events::{OrderFilled, OrderCancelled, BidCancelled}, errors as Errors,
};

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
        0x7cdfb9010d274c820449ed9992fe536b5f39bd7f9895ffc4b03890e7d223609,
        0x4aef0200250ccd0c035b44deed85143afc7cb73bfb231ea313e74049221d1a9
    ]
        .span()
}
pub fn OFFER_SIGNATURES() -> Span<felt252> {
    array![
        0x8e4f2e62cd2f90e03dd3bf11dfb386ebbbf055e73da762ab38ae32a30fe4df,
        0x52dabad9e0e9a446f1e2ab4d4519ca308008ee43cb1c8e8e4a6f1d358cdca1d
    ]
        .span()
}
pub fn BID_SIGNATURES() -> (Span<felt252>, Span<felt252>, Span<felt252>) {
    (
        array![
            0x592161e15972fe40f0eb72af55ab43f5348b6a2547a276758920eb6ed805882,
            0x7c4d82030882a2d980e02b53e39a91822e5e45f2d13a05c4515678bf536bfff
        ]
            .span(),
        array![
            0x3b7322829b23e6bc68cf7eda509451f43fff6707dd06f48b622796093f17204,
            0x3d2a4aef4ebac578454e50a5437006a2b7b2cfcb77dda430836830ee437b75e
        ]
            .span(),
        array![
            0x5d27957bc6b9d4960e284e6b104e1b8992ed0fbad1f316b7c6c7aa9d33e2724,
            0xbf102f4a8acbe4309742dd1222ef25310e3d82344a1701a64d719aa47c4fd6
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

    constructor_calldata.append_serde(OWNER());
    constructor_calldata.append_serde(eth_address);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
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

pub fn deploy_erc721() -> ContractAddress {
    let contract = declare("OpenMarkNFT").unwrap();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(TEST_SELLER);
    constructor_calldata.append_serde(OPENMARK_NFT_NAME());
    constructor_calldata.append_serde(OPENMARK_NFT_SYMBOL());
    constructor_calldata.append_serde(OPENMARK_NFT_BASE_URI());

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

pub fn deploy_erc721_at(addr: ContractAddress) -> ContractAddress {
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
    Order,
    Span<felt252>,
    IOpenMarkDispatcher,
    ContractAddress,
    IERC721Dispatcher,
    ContractAddress,
    IERC20Dispatcher,
    ContractAddress,
    ContractAddress,
    ContractAddress,
) {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());
    let eth_address: ContractAddress = TEST_ETH_ADDRESS.try_into().unwrap();

    let openmark_address = deploy_openmark();
    let seller: ContractAddress = TEST_SELLER.try_into().unwrap();
    let buyer: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: erc721_address };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: eth_address };

    let order = Order {
        nftContract: erc721_address,
        tokenId: 2,
        price: 3,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(erc721_address, seller);

        let IOM721Dispatcher = IOM721TokenDispatcher { contract_address: erc721_address };
        IOM721Dispatcher.safe_batch_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, 2);
    }

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    ERC20Dispatcher.approve(openmark_address, 3);

    let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

    (
        order,
        SELL_SIGNATURES(),
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    )
}

pub fn create_offer() -> (
    Order,
    Span<felt252>,
    IOpenMarkDispatcher,
    ContractAddress,
    IERC721Dispatcher,
    ContractAddress,
    IERC20Dispatcher,
    ContractAddress,
    ContractAddress,
    ContractAddress,
) {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());
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
        price: price,
        salt: 4,
        expiry: 5,
        option: OrderType::Offer,
    };

    // create and approve nft
    {
        start_cheat_caller_address(erc721_address, seller);

        let IOM721Dispatcher = IOM721TokenDispatcher { contract_address: erc721_address };
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

    let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

    (
        order,
        OFFER_SIGNATURES(),
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    )
}

pub fn create_bids() -> (
    Span<SignedBid>,
    Span<Bid>,
    IOpenMarkDispatcher,
    ContractAddress,
    IERC721Dispatcher,
    ContractAddress,
    IERC20Dispatcher,
    ContractAddress,
    ContractAddress,
    Span<ContractAddress>,
    Span<u128>,
    u128
) {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());
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
    let bid1 = Bid { nftContract: erc721_address, amount: 1, unitPrice, salt: 4, expiry: 5, };
    let bid2 = Bid { nftContract: erc721_address, amount: 2, unitPrice, salt: 4, expiry: 5, };
    let bid3 = Bid { nftContract: erc721_address, amount: 3, unitPrice, salt: 4, expiry: 5, };

    // create and approve nfts
    {
        let IOM721Dispatcher = IOM721TokenDispatcher { contract_address: erc721_address };
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

    // accept bids and verify
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };
    let (sig1, sig2, sig3) = BID_SIGNATURES();
    let signed_bids = array![
        SignedBid { bidder: buyer1, bid: bid1, signature: sig1 },
        SignedBid { bidder: buyer2, bid: bid2, signature: sig2 },
        SignedBid { bidder: buyer3, bid: bid3, signature: sig3 },
    ];

    let tokenIds = array![0, 1, 2, 3, 4, 5].span();

    (
        signed_bids.span(),
        array![bid1, bid2, bid3].span(),
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        array![buyer1, buyer2, buyer3].span(),
        tokenIds,
        unitPrice
    )
}

pub fn get_contract_state_for_testing() -> ContractState {
    let mut state = openmark::openmark::OpenMark::contract_state_for_testing();
    state.maxBids.write(10);

    state
}
