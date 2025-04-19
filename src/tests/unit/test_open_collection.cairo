// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use openzeppelin::token::erc721::interface::{
    IERC721DispatcherTrait, IERC721Dispatcher, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait,
};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::{ContractAddress};
use openmark::{assets::interface::{IOpenCollectionDispatcher, IOpenCollectionDispatcherTrait}};
use openmark::tests::unit::common::{toAddress, BUYER1, SELLER1};
use openzeppelin::utils::serde::SerializedAppend;
use openmark::assets::open_collection::OpenCollection;

use snforge_std::{spy_events};
use snforge_std::EventSpyAssertionsTrait;

use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use openmark::{
    core::interface::{
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMarkManagerDispatcher,
        IOpenMarkManagerDispatcherTrait,
    },
};

use openmark::tests::unit::common::{
    OM_OWNER, NFT_OWNER, TEST_NFT, setup_balance_at, TEST_PAYMENT, deploy_openmark, ROYALTY,
};
use openmark::core::OpenMark;
use openmark::primitives::constants::{PERMYRIAD};
use openmark::primitives::types::{Order, OrderType};
use openmark::core::events::{OrderFilled};

// Helper constants
fn NFT_NAME() -> ByteArray {
    "OpenMark Collection"
}

fn NFT_SYMBOL() -> ByteArray {
    "OMC"
}

// Deploy OpenCollection contract
fn deploy_open_collection(
    owner: ContractAddress, name: ByteArray, symbol: ByteArray,
) -> ContractAddress {
    let contract = declare("OpenCollection").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

// Helper to create OpenCollection with default values
fn create_open_collection(owner: ContractAddress) -> ContractAddress {
    deploy_open_collection(owner, NFT_NAME(), NFT_SYMBOL())
}

#[test]
fn test_mint_uris_works() {
    // Setup
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_open_collection(owner);
    let to: ContractAddress = toAddress(BUYER1);

    let open_collection = IOpenCollectionDispatcher { contract_address };
    let erc721 = IERC721Dispatcher { contract_address };

    // Prepare URIs
    let uris = array![
        "ipfs://QmUMGWrnyeuPkARUYMUf5U9NWo8uihRGnhLH5yk3rzdUX6/0",
        "ipfs://QmfFYf8G2Y9dvbnT843NFQs4evfJEJK1XHwo2qySjpHJ4e/1",
    ]
        .span();

    // Act: Mint URIs as owner
    start_cheat_caller_address(contract_address, owner);

    let mut spy = spy_events();
    open_collection.mintURIs(to, uris);
    let expected_event1 = OpenCollection::Event::TokenMinted(
        OpenCollection::TokenMinted {
            to, token_id: 0, uri: "ipfs://QmUMGWrnyeuPkARUYMUf5U9NWo8uihRGnhLH5yk3rzdUX6/0",
        },
    );

    let expected_event2 = OpenCollection::Event::TokenMinted(
        OpenCollection::TokenMinted {
            to, token_id: 1, uri: "ipfs://QmfFYf8G2Y9dvbnT843NFQs4evfJEJK1XHwo2qySjpHJ4e/1",
        },
    );

    spy.assert_emitted(@array![(contract_address, expected_event1)]);
    spy.assert_emitted(@array![(contract_address, expected_event2)]);

    // Assert: Check ownership
    assert(erc721.owner_of(0) == to, 'Token 0 owner incorrect');
    assert(erc721.owner_of(1) == to, 'Token 1 owner incorrect');

    // Assert: Check token index
    assert(open_collection.getTokenIndex() == 2, 'Token index should be 2');

    // Assert: Check stored URIs
    let metadata_dispatcher = IERC721MetadataDispatcher { contract_address: contract_address };
    assert(
        metadata_dispatcher
            .token_uri(0) == "ipfs://QmUMGWrnyeuPkARUYMUf5U9NWo8uihRGnhLH5yk3rzdUX6/0",
        'Token 0 URI incorrect',
    );
    assert(
        metadata_dispatcher
            .token_uri(1) == "ipfs://QmfFYf8G2Y9dvbnT843NFQs4evfJEJK1XHwo2qySjpHJ4e/1",
        'Token 1 URI incorrect',
    );
}


pub fn setup_erc721_at(addr: ContractAddress, receiver: ContractAddress) -> ContractAddress {
    let contract = declare("OpenCollection").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(NFT_NAME());
    constructor_calldata.append_serde(NFT_SYMBOL());
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();

    let collectionDispatcher = IOpenCollectionDispatcher { contract_address };
    collectionDispatcher.mintURIs(receiver, ["", "", "", ""].span());
    contract_address
}

#[test]
fn buy_works() {
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let seller: ContractAddress = toAddress(SELLER1);
    let nft_token = setup_erc721_at(toAddress(TEST_NFT), seller);
    let buyer: ContractAddress = toAddress(BUYER1);

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

    let commission = 500; // 5%
    // setup commission and royalty
    let manager_dispatcher = IOpenMarkManagerDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(openmark_address, toAddress(OM_OWNER));
    manager_dispatcher.set_commission(commission);

    // buy and verify
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, seller);

    start_cheat_caller_address(payment_token, buyer);
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, openmark_address);

    let mut spy = spy_events();
    openmark.buy(seller, order, signature.span());

    let expected_event = OpenMark::Event::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let owner_balance = payment_dispatcher.balance_of(toAddress(OM_OWNER));
    let nft_owner_balance = payment_dispatcher.balance_of(toAddress(NFT_OWNER));

    let price: u256 = (order.price * order.value).into();
    let commission = price * commission / PERMYRIAD;
    let royalty = 0;
    let payout = price - commission - royalty;

    assert(nft_dispatcher.owner_of(order.tokenId.into()) == buyer, 'NFT owner not correct');
    assert(
        buyer_after_balance == buyer_before_balance - order.price.into(),
        'Buyer balance not correct',
    );
    assert(seller_after_balance == seller_before_balance + payout, 'Seller balance not correct');
    assert(owner_balance == commission, 'commission not correct');
    assert(nft_owner_balance == royalty, 'royalty not correct');
}
