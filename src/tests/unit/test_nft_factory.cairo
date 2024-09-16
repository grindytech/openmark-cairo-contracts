use openmark::factory::interface::INFTFactoryDispatcherTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use openmark::factory::interface::{INFTFactoryDispatcher};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait,get_class_hash,
};
use starknet::{ContractAddress};

use openmark::factory::nft_factory::NFTFactory::Event as FactoryEvent;
use openmark::factory::nft_factory::NFTFactory::CollectionCreated;
use openmark::tests::unit::common::{create_openmark_nft, SELLER1};

fn deloy_nft_factory() -> (ContractAddress, INFTFactoryDispatcher) {
    let nft_token = create_openmark_nft();
    let nft_classhash = get_class_hash(nft_token);

    let contract = declare("NFTFactory").unwrap();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(nft_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, INFTFactoryDispatcher { contract_address })
}

#[test]
fn create_collection_works() {
    let (_contract_address, factory_contract) = deloy_nft_factory();

    factory_contract
        .create_collection(
            0, SELLER1.try_into().unwrap(), "Starknet NFT", "Stark NFT", "https://starknet.io", 1000_u256
        );

    let nft_address = factory_contract.get_collection(0);

    let _expected_event = FactoryEvent::CollectionCreated(
        CollectionCreated {
            id: 0,
            address: nft_address,
            owner: SELLER1.try_into().unwrap(),
            name: "Starknet NFT",
            symbol: "Stark NFT",
            base_uri: "https://starknet.io",
            total_supply: 1000_u256,
        }
    );
}

#[test]

#[should_panic(expected: ('OMFactory: ID in use',))]
fn create_collection_id_used_panics() {
    let (_, factory_contract) = deloy_nft_factory();

    factory_contract
        .create_collection(
            0, SELLER1.try_into().unwrap(), "Starknet NFT", "Stark NFT", "https://starknet.io", 1000_u256
        );
    factory_contract
        .create_collection(
            0, SELLER1.try_into().unwrap(), "Starknet", "Stark", "https://starknet.io", 1000_u256
        );
}
