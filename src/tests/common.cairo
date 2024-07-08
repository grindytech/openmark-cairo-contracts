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
    events::{OrderFilled, OrderCancelled, BidsFilled, BidCancelled}, errors as Errors,
};

pub const TEST_ETH_ADDRESS: felt252 =
    0x64948D425BCD9983F21E80124AFE95D1D6987717380B813FAD8A3EA2C4D31C8;
pub const TEST_ERC721_ADDRESS: felt252 =
    0x52D3AA5AF7D5A5D024F99EF80645C32B0E94C9CC4645CDA09A36BE2696257AA;
pub const TEST_SELLER: felt252 = 0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2;

pub const TEST_BUYER1: felt252 = 0x913b4e904ab75554db59b64e1d26116d1ba1c033ce57519b53e35d374ef2dd;
pub const TEST_BUYER2: felt252 = 0x30f0a5f5311ad0fa15cf1f8c22677c366ad0fd66d9e5ca588957ada394430f8;
pub const TEST_BUYER3: felt252 = 0x4136107a5d3c1a6cd4c28693ea6a0e5bb9ffa648467629a9900183cf623c40a;

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
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn deploy_erc721_at(addr: ContractAddress) -> ContractAddress {
    let contract = declare("OpenMarkNFT").unwrap();

    let mut constructor_calldata = array![];
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
        IOM721Dispatcher.safe_mint(seller, 5);

        ERC721Dispatcher.approve(openmark_address, 2);
    }

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    ERC20Dispatcher.approve(openmark_address, 3);

    let mut signature = array![
        0x5228d8ebab110b3038c328892e8293c49ef8777f02de0e094c1a902e91e0271,
        0x72ac0a9ad3fd5ad9143a720148d174e724aa752dfedc6e4dce767b82cbbd913
    ];
    let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

    (
        order,
        signature.span(),
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
        IOM721Dispatcher.safe_mint(seller, 5);

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

    let mut signature = array![
        0x431ba689471acd01b7642947c74f4048beb2232ab214f85c667d9328c5067c0,
        0x57a29a567e6240506f8d03682f4ac7d970afc3f228da7a96b942306d8b966f1
    ];
    let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

    (
        order,
        signature.span(),
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
        IOM721Dispatcher.safe_mint(seller, total_amount);

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

    let mut signature1 = array![
        0x3c0ac7eca879533ffd6de6b6ef8630889a92b6f55844b4aefdb037443018c4d,
        0x43ce88b1de27d39b8f8a88fc378792cacb39b67099161c835f66c5ddefe7ddd
    ];

    let mut signature2 = array![
        0x7798f7bc30a529cc8e028fa9c6051830f2d93443aefe4c27a68d374c19f793b,
        0x2edf5d0fb4fb82aa11d248be4e86131c61d4f36d9f1582b8cf6beba616a470e
    ];
    let mut signature3 = array![
        0x726519bf95b826c33780898daccbf9fe0c602371ad218dfa8f4ef669fa6f52d,
        0x2d4ca8c22cff30189e5914db40107a12a2908fc958bbd3bd264c474a075436e
    ];

    let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

    let signed_bids = array![
        SignedBid { bidder: buyer1, bid: bid1, signature: signature1.span() },
        SignedBid { bidder: buyer2, bid: bid2, signature: signature2.span() },
        SignedBid { bidder: buyer3, bid: bid3, signature: signature3.span() },
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
