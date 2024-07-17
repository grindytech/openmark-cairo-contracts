use core::array::SpanTrait;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy, Event,
    start_cheat_block_timestamp,
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    token::interface::{
        IOpenMarkNFTDispatcher, IOpenMarkNFTDispatcherTrait, IOpenMarNFTkMetadataDispatcher,
        IOpenMarNFTkMetadataDispatcherTrait
    },
    token::events::{TokenMinted, TokenURIUpdated},
    token::openmark_nft::OpenMarkNFT::Event as NFTEvents,
};
use openmark::tests::common::{create_openmark_nft, TEST_BUYER1, TEST_SELLER};

#[test]
#[available_gas(2000000)]
fn safe_mint_works() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let mut spy = spy_events(SpyOn::One(contract_address));

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_mint(to);
    OpenMarkNFT.safe_mint(to);

    assert_eq!(ERC721.owner_of(0), to);
    assert_eq!(ERC721.owner_of(1), to);

    let expected_event = NFTEvents::TokenMinted(
        TokenMinted { caller: owner, to, token_id: 1, uri: "" }
    );
    spy.assert_emitted(@array![(contract_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
fn safe_mint_with_uri_works() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let mut spy = spy_events(SpyOn::One(contract_address));

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_mint_with_uri(to, "hello");

    assert_eq!(ERC721.owner_of(0), to);

    let expected_event = NFTEvents::TokenMinted(
        TokenMinted { caller: owner, to, token_id: 0, uri: "hello" }
    );
    spy.assert_emitted(@array![(contract_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
fn safe_batch_mint_works() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let mut spy = spy_events(SpyOn::One(contract_address));

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_batch_mint(to, 10);

    assert_eq!(ERC721.owner_of(9), to);

    let expected_event = NFTEvents::TokenMinted(
        TokenMinted { caller: owner, to, token_id: 9, uri: "" }
    );
    spy.assert_emitted(@array![(contract_address, expected_event)]);
}


#[test]
#[available_gas(2000000)]
fn safe_batch_mint_with_uris_works() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();
    let mut spy = spy_events(SpyOn::One(contract_address));
    let uris = array!["aaa", "bbb", "ccc"];
    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_batch_mint_with_uris(to, uris.span());

    assert_eq!(ERC721.owner_of(2), to);

    let expected_event = NFTEvents::TokenMinted(
        TokenMinted { caller: owner, to, token_id: 2, uri: "ccc" }
    );
    spy.assert_emitted(@array![(contract_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
fn set_token_uri_works() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    let mut spy = spy_events(SpyOn::One(contract_address));

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_mint(to);

    start_cheat_caller_address(contract_address, to);
    OpenMarkNFT.set_token_uri(0, "ccc");

    let OpenMarkNFT = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(OpenMarkNFT.token_uri(0), "ccc");

    let expected_event = NFTEvents::TokenURIUpdated(
        TokenURIUpdated { who: to, token_id: 0, uri: "ccc" }
    );
    spy.assert_emitted(@array![(contract_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
fn set_base_uri_works() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_mint(to);
    OpenMarkNFT.set_base_uri("https://api.openmark.io/");
    let OpenMarkNFT = IOpenMarNFTkMetadataDispatcher { contract_address };
    assert_eq!(OpenMarkNFT.token_uri(0), "https://api.openmark.io/0");
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn set_token_uri_unauthorized_panics() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let owner: ContractAddress = TEST_SELLER.try_into().unwrap();
    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    start_cheat_caller_address(contract_address, owner);
    OpenMarkNFT.safe_mint(to);

    OpenMarkNFT.set_token_uri(0, "ccc");
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn set_base_uri_unauthorized_panics() {
    let contract_address = create_openmark_nft();
    let OpenMarkNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = TEST_BUYER1.try_into().unwrap();

    start_cheat_caller_address(contract_address, to);
    OpenMarkNFT.set_base_uri("ccc");
}
