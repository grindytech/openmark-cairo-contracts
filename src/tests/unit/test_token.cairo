use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use starknet::{ContractAddress};

use openmark::{
    token::interface::{IOpenMarkNFTDispatcher, IOpenMarkNFTDispatcherTrait},
    token::interface::{IOMERC721Dispatcher, IOMERC721DispatcherTrait},
};
use openmark::tests::unit::common::{toAddress, BUYER1, SELLER1};

pub fn NFT_NAME() -> ByteArray {
    "OpenMark"
}

pub fn NFT_SYMBOL() -> ByteArray {
    "OM"
}

pub fn NFT_BASE_URI() -> ByteArray {
    ""
}
pub fn do_create_gameitem(
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    baseURI: ByteArray,
    totalSupply: u256
) -> ContractAddress {
    let contract = declare("GameItem").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(baseURI);
    constructor_calldata.append_serde(totalSupply);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_gameitem(owner: ContractAddress,) -> ContractAddress {
    return do_create_gameitem(owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100);
}

#[test]
fn safe_batch_mint_works() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_gameitem(owner);

    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OpenNFT.safe_batch_mint(to, 10);

    assert(ERC721.owner_of(9) == to, 'NFT owner not correct');
}

#[test]
fn safe_batch_mint_with_uris_works() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_gameitem(owner);

    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let owner: ContractAddress = toAddress(SELLER1);
    let to: ContractAddress = toAddress(BUYER1);

    let uris = array!["aaa", "bbb", "ccc"];
    start_cheat_caller_address(contract_address, owner);
    OpenNFT.safe_batch_mint_with_uris(to, uris.span());

    assert(ERC721.owner_of(2) == to, 'NFT owner not correct');
}

#[test]
fn get_token_uri_only_baseURI_works() {
    // Set the base URI and mint a token without a specific URI
    // If only base URI is set, the token URI should concatenate the base URI and token ID
    let owner: ContractAddress = toAddress(SELLER1);
    let to: ContractAddress = toAddress(BUYER1);

    let baseURI = "https://api.openmark.io/";
    let contract_address = do_create_gameitem(owner, "NAME", "SYMBOL", baseURI, 100);

    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    let NFTMetadata = IOMERC721Dispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    OpenNFT.safe_batch_mint(to, 1);

    assert(NFTMetadata.token_uri(0) == "https://api.openmark.io/0", 'Token uri not correct');
}


#[test]
fn get_token_uri_without_baseURI_works() {
    // Set an empty base URI and mint a token with a specific URI
    // If there is no base URI, the token URI should be the specific URI set during minting
    let owner: ContractAddress = toAddress(SELLER1);
    let to: ContractAddress = toAddress(BUYER1);

    let contract_address = do_create_gameitem(owner, "NAME", "SYMBOL", "", 100);
    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    let NFTMetadata = IOMERC721Dispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);

    OpenNFT.safe_batch_mint_with_uris(to, array!["TOKEN1"].span());
    assert(NFTMetadata.token_uri(0) == "TOKEN1", 'Token uri not correct');
}

#[test]
fn get_token_uri_with_baseURI_and_tokenURI_works() {
    // Set the base URI again and mint a token with a specific URI
    // If both base URI and specific token URI are set, the token URI
    // should concatenate the base URI and specific token URI

    let baseURI = "https://api.openmark.io/";
    let owner: ContractAddress = toAddress(SELLER1);
    let to: ContractAddress = toAddress(BUYER1);

    let contract_address = do_create_gameitem(owner, "NAME", "SYMBOL", baseURI, 100);
    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    let NFTMetadata = IOMERC721Dispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);

    OpenNFT.safe_batch_mint_with_uris(to, array!["TOKEN2"].span());
    assert(NFTMetadata.token_uri(0) == "https://api.openmark.io/TOKEN2", 'Token uri not correct');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn safe_batch_mint_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_gameitem(owner);

    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OpenNFT.safe_batch_mint(to, 10);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn safe_batch_mint_with_uris_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_gameitem(owner);

    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OpenNFT.safe_batch_mint_with_uris(to, array!["a", "b"].span());
}

#[test]
#[should_panic(expected: ('OMNFT: exceed total supply',))]
fn safe_batch_mint_exceed_total_supply_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let totalSupply = 5_u256;
    let contract_address = do_create_gameitem(owner, "NAME", "SYMBOL", "", totalSupply);
    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);

    OpenNFT.safe_batch_mint(owner, totalSupply + 1);
}

#[test]
#[should_panic(expected: ('OMNFT: exceed total supply',))]
fn safe_batch_mint_with_uris_exceed_total_supply_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let totalSupply = 5_u256;
    let contract_address = do_create_gameitem(owner, "NAME", "SYMBOL", "", totalSupply);
    let OpenNFT = IOpenMarkNFTDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);

    OpenNFT.safe_batch_mint_with_uris(owner, array!["1", "2", "3", "4", "5", "6"].span());
}
