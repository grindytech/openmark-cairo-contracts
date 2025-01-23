use openmark::factory::interface::{
    IOERC721FactoryDispatcher, IOERC721FactoryDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, get_class_hash,  DeclareResultTrait
};
use starknet::{ContractAddress};

use openmark::factory::oerc721_factory::OERC721Factory::Event as NFTEvents;
use openmark::factory::oerc721_factory::OERC721Factory::CollectionCreated;

use openmark::tests::unit::common::{
    create_test_oerc721, SELLER1, toAddress,
};

fn create_nft_factory() -> (ContractAddress, IOERC721FactoryDispatcher) {
    let nft_token = create_test_oerc721();
    let nft_classhash = get_class_hash(nft_token);

    let contract = declare("OERC721Factory").unwrap().contract_class();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(nft_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, IOERC721FactoryDispatcher { contract_address })
}

#[test]
fn create_collection_works() {
    let (_contract_address, factory_contract) = create_nft_factory();

    factory_contract
        .create_collection(
            0,
            toAddress(SELLER1),
            "Starknet NFT",
            "Stark NFT",
            "https://starknet.io",
            1000_u256,
            0_u256
        );

    let nft_address = factory_contract.get_collection(0);

    let _expected_event = NFTEvents::CollectionCreated(
        CollectionCreated {
            id: 0,
            address: nft_address,
            owner: toAddress(SELLER1),
            name: "Starknet NFT",
            symbol: "Stark NFT",
            base_uri: "https://starknet.io",
            total_supply: 1000_u256,
            royalty_percentage: 0_u256,
        }
    );
}

#[test]
#[should_panic(expected: ('OM: ID in use',))]
fn create_collection_id_used_panics() {
    let (_, factory_contract) = create_nft_factory();

    factory_contract
        .create_collection(
            0,
            toAddress(SELLER1),
            "Starknet NFT",
            "Stark NFT",
            "https://starknet.io",
            1000_u256,
            0_u256
        );

    factory_contract
        .create_collection(
            0, toAddress(SELLER1), "Starknet", "Stark", "https://starknet.io", 1000_u256, 0_u256
        );
}
