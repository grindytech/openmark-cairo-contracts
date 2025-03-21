// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::{ContractAddress};
use openmark::{assets::interface::{IOpenCollectionDispatcher, IOpenCollectionDispatcherTrait}};
use openmark::tests::unit::common::{toAddress, BUYER1, SELLER1};
use openzeppelin::utils::serde::SerializedAppend;

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
    open_collection.mintURIs(to, uris);

    // Assert: Check ownership
    assert(erc721.owner_of(0) == to, 'Token 0 owner incorrect');
    assert(erc721.owner_of(1) == to, 'Token 1 owner incorrect');

    // Assert: Check token index
    assert(open_collection.getTokenIndex() == 2, 'Token index should be 2');

    // Assert: Check stored URIs
    assert(
        open_collection
            .openTokenURI(0) == "ipfs://QmUMGWrnyeuPkARUYMUf5U9NWo8uihRGnhLH5yk3rzdUX6/0",
        'Token 0 URI incorrect',
    );
    assert(
        open_collection
            .openTokenURI(1) == "ipfs://QmfFYf8G2Y9dvbnT843NFQs4evfJEJK1XHwo2qySjpHJ4e/1",
        'Token 1 URI incorrect',
    );
}
