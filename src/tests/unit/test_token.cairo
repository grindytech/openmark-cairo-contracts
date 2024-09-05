use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address
};

use starknet::{ContractAddress};

use openmark::{
    token::interface::{
        IOpenMarkNFTDispatcher, IOpenMarkNFTDispatcherTrait, IOpenMarNFTkMetadataDispatcher,
        IOpenMarNFTkMetadataDispatcherTrait
    },
    token::events::{TokenMinted, TokenURIUpdated},
    token::openmark_nft::OpenMarkNFT::Event as NFTEvents,
};
use openmark::tests::unit::common::{TEST_BUYER1, TEST_SELLER};

pub fn NFT_NAME() -> ByteArray {
    "OpenMark"
}

pub fn NFT_SYMBOL() -> ByteArray {
    "OM"
}

pub fn NFT_BASE_URI() -> ByteArray {
    ""
}

pub fn create_gameitem(
    owner: ContractAddress,
) -> ContractAddress {
    let contract = declare("GameItem").unwrap();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(NFT_NAME());
    constructor_calldata.append_serde(NFT_SYMBOL());
    constructor_calldata.append_serde(NFT_BASE_URI());

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    contract_address
}

#[test]
fn safe_batch_mint_works() {
    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    // let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_batch_mint(to, 10);

    assert_eq!(ERC721.owner_of(9), to);

    let _expected_event = NFTEvents::TokenMinted(
        TokenMinted { to, token_id: 9, uri: "" }
    );
//    spy
//         .assert_emitted(
//             @array![
//                 (contract_address, expected_event),
//             ]
//         );
}


#[test]
fn safe_batch_mint_with_uris_works() {
     let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    // let mut spy = spy_events();
    let uris = array!["aaa", "bbb", "ccc"];
    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_batch_mint_with_uris(to, uris.span());

    assert_eq!(ERC721.owner_of(2), to);

    let _expected_event = NFTEvents::TokenMinted(
        TokenMinted { to, token_id: 2, uri: "ccc" }
    );
//    spy
//         .assert_emitted(
//             @array![
//                 (contract_address, expected_event),
//             ]
//         );
}

#[test]
fn set_token_uri_works() {
    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.set_base_uri("");

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_batch_mint(to, 10);

    // let mut spy = spy_events();
    OpenMarkNFT.set_token_uri(0, "ccc");
    let OpenMarkNFT = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(OpenMarkNFT.token_uri(0), "ccc");

    let _expected_event = NFTEvents::TokenURIUpdated(
        TokenURIUpdated { token_id: 0, uri: "ccc" }
    );
//    spy
//         .assert_emitted(
//             @array![
//                 (contract_address, expected_event),
//             ]
//         );
}

#[test]
fn set_base_uri_works() {
     let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
        OpenMarkNFT.safe_batch_mint(to, 10);
    OpenMarkNFT.set_base_uri("https://api.openmark.io/");
    let OpenMarkNFT = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(OpenMarkNFT.token_uri(0), "https://api.openmark.io/0");
}

#[test]
fn get_token_uri_works() {
    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    start_cheat_caller_address(contract_address, owner);

    // 1. Set the base URI and mint a token without a specific URI
    // If only base URI is set, the token URI should concatenate the base URI and token ID
    OpenMarkNFT.safe_batch_mint(to, 1);
    OpenMarkNFT.set_base_uri("https://api.openmark.io/");
    let MetadataDispatcher = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(MetadataDispatcher.token_uri(0), "https://api.openmark.io/0");

    // 2. Set an empty base URI and mint a token with a specific URI
    // If there is no base URI, the token URI should be the specific URI set during minting
    OpenMarkNFT.set_base_uri("");
    OpenMarkNFT.safe_batch_mint_with_uris(to, array!["TOKEN1"].span());
    let MetadataDispatcher = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(MetadataDispatcher.token_uri(1), "TOKEN1");

    // 3. Set the base URI again and mint a token with a specific URI
    // If both base URI and specific token URI are set, the token URI should concatenate the base URI and specific token URI
    OpenMarkNFT.set_base_uri("https://api.openmark.io/");
    OpenMarkNFT.safe_batch_mint_with_uris(to, array!["TOKEN2"].span());
    let MetadataDispatcher = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(MetadataDispatcher.token_uri(2), "https://api.openmark.io/TOKEN2");
}

#[test]

#[should_panic(expected: ('Caller is missing role',))]
fn safe_batch_mint_unauthorized_panics() {
let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    start_cheat_caller_address(contract_address, to);
    OpenMarkNFT.safe_batch_mint(to, 10);
}


#[test]

#[should_panic(expected: ('Caller is missing role',))]
fn safe_batch_mint_with_uris_unauthorized_panics() {
let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    start_cheat_caller_address(contract_address, to);
    OpenMarkNFT.safe_batch_mint_with_uris(to, array!["a", "b"].span());
}


#[test]

#[should_panic(expected: ('Caller is missing role',))]
fn set_token_uri_unauthorized_panics() {
    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_batch_mint(to, 10);

    start_cheat_caller_address(contract_address, to);
    OpenMarkNFT.set_token_uri(0, "ccc");
}

#[test]

#[should_panic(expected: ('Caller is missing role',))]
fn set_base_uri_unauthorized_panics() {
let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let contract_address = create_gameitem(owner);

    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    start_cheat_caller_address(contract_address, to);
    OpenMarkNFT.set_base_uri("ccc");
}
