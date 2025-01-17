use openzeppelin::token::erc1155::interface::{
    IERC1155Dispatcher, IERC1155DispatcherTrait, IERC1155MetadataURIDispatcher,
    IERC1155MetadataURIDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use starknet::{ContractAddress};

use openmark::{
    assets::interface::{
        IERC1155MinterDispatcher, IERC1155MinterDispatcherTrait
    }, // assets::interface::{IOMERC1155Dispatcher, IOMERC1155DispatcherTrait},
};
use openmark::tests::unit::common::{setup_account, BUYER1, SELLER1};

pub fn NFT_NAME() -> ByteArray {
    "OpenMark"
}

pub fn NFT_SYMBOL() -> ByteArray {
    "OM"
}

pub fn NFT_BASE_URI() -> ByteArray {
    ""
}
pub fn do_create_oerc1155(
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    URI: ByteArray,
    totalSupply: u256,
    royaltyPercentage: u256,
) -> ContractAddress {
    let contract = declare("OERC1155").unwrap().contract_class();
    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(name);
    constructor_calldata.append_serde(symbol);
    constructor_calldata.append_serde(URI);
    constructor_calldata.append_serde(totalSupply);
    constructor_calldata.append_serde(royaltyPercentage);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

pub fn create_oerc1155(owner: ContractAddress,) -> ContractAddress {
    return do_create_oerc1155(owner, NFT_NAME(), NFT_SYMBOL(), NFT_BASE_URI(), 100, 0);
}

#[test]
fn mint_works() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc1155(owner);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };
    let ERC1155 = IERC1155Dispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC1155.mint(to, 10, 10, [].span());

    assert(ERC1155.balance_of(to, 10) == 10, 'NFT balance not correct');
}

#[test]
fn mintBatch_works() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc1155(owner);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };
    let ERC1155 = IERC1155Dispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC1155.mintBatch(to, [1, 10].span(), [10, 10].span(), [].span());

    assert(ERC1155.balance_of(to, 1) == 10, 'NFT balance not correct');
    assert(ERC1155.balance_of(to, 10) == 10, 'NFT balance not correct');
}

#[test]
fn get_token_uri_only_baseURI_works() {
    // Set the base URI and mint a token without a specific URI
    // If only base URI is set, the token URI should concatenate the base URI and token ID
    let owner: ContractAddress = setup_account(SELLER1);
    let to: ContractAddress = setup_account(BUYER1);

    let baseURI = "https://api.openmark.io/{id}";
    let contract_address = do_create_oerc1155(owner, "NAME", "SYMBOL", baseURI.clone(), 100, 0);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };
    let NFTMetadata = IERC1155MetadataURIDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    OERC1155.mintBatch(to, [0, 10].span(), [10, 10].span(), [].span());

    assert(NFTMetadata.uri(1) == baseURI.clone(), 'Token uri not correct');
    assert(NFTMetadata.uri(10) == baseURI, 'Token uri not correct');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn mint_unauthorized_panics() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc1155(owner);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC1155.mint(to, 10, 10, [].span());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn mintBatch_unauthorized_panics() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc1155(owner);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, to);
    OERC1155.mintBatch(to, [1, 10].span(), [10, 10].span(), [].span());
}

#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn mint_invalid_token_id_panics() {
    let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc1155(owner);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC1155.mint(to, 1000, 10, [].span());
}

#[test]
#[should_panic(expected: ('OM: invalid tokenId',))]
fn mintBatch_token_id_panics() {
  let owner: ContractAddress = setup_account(SELLER1);
    let contract_address = create_oerc1155(owner);

    let OERC1155 = IERC1155MinterDispatcher { contract_address };

    let to: ContractAddress = setup_account(BUYER1);
    start_cheat_caller_address(contract_address, owner);
    OERC1155.mintBatch(to, [1, 1000].span(), [10, 10].span(), [].span());
}
