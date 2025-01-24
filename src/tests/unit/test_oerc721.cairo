use openzeppelin::token::erc721::interface::{
    IERC721DispatcherTrait, IERC721Dispatcher, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait
};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use starknet::{ContractAddress};

use openmark::{
    assets::interface::{
        IERC721MinterDispatcher, IERC721MinterDispatcherTrait
    }, // assets::interface::{IOMERC721Dispatcher, IOMERC721DispatcherTrait},
};
use openmark::tests::unit::common::{toAddress, setup_account, BUYER1, SELLER1};

pub fn NFT_NAME() -> ByteArray {
    "OpenMark"
}

pub fn NFT_SYMBOL() -> ByteArray {
    "OM"
}

pub fn NFT_BASE_URI() -> ByteArray {
    ""
}
pub fn do_create_oerc721(
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    baseURI: ByteArray,
    totalSupply: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC721").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(baseURI);
    constructor_calldata.append_serde(totalSupply);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_oerc721(owner: ContractAddress,) -> ContractAddress {
    return do_create_oerc721(owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, 0);
}

#[test]
fn mint_works() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.mint(to, 10);

    assert(ERC721.owner_of(10) == to, 'NFT owner not correct');
}

#[test]
fn safe_mint_works() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.safe_mint(to, 10, [].span());

    assert(ERC721.owner_of(10) == to, 'NFT owner not correct');
}

#[test]
fn safeMint_works() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.safeMint(to, 10, [].span());

    assert(ERC721.owner_of(10) == to, 'NFT owner not correct');
}

#[test]
fn mintBatch_works() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.mintBatch(to, [1, 10].span());

    assert(ERC721.owner_of(1) == to, 'NFT owner not correct');
    assert(ERC721.owner_of(10) == to, 'NFT owner not correct');
}

#[test]
fn safeMintBatch_works() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };
    let ERC721 = IERC721Dispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.safeMintBatch(to, [10].span(), [].span());

    assert(ERC721.owner_of(10) == to, 'NFT owner not correct');
}

#[test]
fn get_token_uri_only_baseURI_works() {
    // Set the base URI and mint a token without a specific URI
    // If only base URI is set, the token URI should concatenate the base URI and token ID
    let owner: ContractAddress = setup_account(SELLER1);
    let to: ContractAddress = setup_account(BUYER1);

    let baseURI = "https://api.openmark.io/";
    let contract_address = do_create_oerc721(owner, "NAME", "SYMBOL", baseURI, 100, 0);

    let OERC721 = IERC721MinterDispatcher { contract_address };
    let NFTMetadata = IERC721MetadataDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    OERC721.mint(to, 0);

    assert(NFTMetadata.token_uri(0) == "https://api.openmark.io/0", 'Token uri not correct');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn mint_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC721.mint(to, 10);
}
#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn safe_mint_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC721.safe_mint(to, 10, [].span());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn safeMint_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC721.safeMint(to, 10, [].span());
}
#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn mintBatch_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC721.mintBatch(to, [1, 10].span());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn safeMintBatch_unauthorized_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC721.safeMintBatch(to, [10].span(), [].span());
}

#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn mint_invalid_token_id_panics() {
    let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.mint(to, 1000);
}
#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn safe_mint_token_id_panics() {
  let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.safe_mint(to, 1000, [].span());
}
#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn safeMint_invalid_token_id_panics() {
     let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.safeMint(to, 1000, [].span());
}
#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn mintBatch_invalid_token_id_panics() {
     let owner: ContractAddress = toAddress(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = toAddress(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.mintBatch(to, [1000, 10].span());
}

#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn safeMintBatch_invalid_token_id_panics() {
     let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc721(owner);

    let OERC721 = IERC721MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC721.safeMintBatch(to, [1000].span(), [].span());
}

