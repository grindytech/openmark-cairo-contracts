use openmark::factory::interface::IOpenMarkFactoryDispatcherTrait;
use core::array::SpanTrait;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use openmark::factory::interface::{IOpenMarkFactoryDispatcher};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address, spy_events,
    SpyOn, EventAssertions, EventSpy, Event, start_cheat_block_timestamp, get_class_hash
};
use starknet::{ContractAddress};

use openmark::factory::openmark_factory::OpenMarkFactory::Event as FactoryEvent;
use openmark::factory::openmark_factory::OpenMarkFactory::CollectionCreated;
use openmark::tests::unit::common::{create_openmark_nft, TEST_SELLER};

fn deloy_openmark_factory() -> (ContractAddress, IOpenMarkFactoryDispatcher) {
    let nft_token = create_openmark_nft();
    let nft_classhash = get_class_hash(nft_token);

    let contract = declare("OpenMarkFactory").unwrap();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(TEST_SELLER);
    constructor_calldata.append_serde(nft_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, IOpenMarkFactoryDispatcher { contract_address })
}

#[test]
#[available_gas(2000000)]
fn create_collection_works() {
    let (contract_address, factory_contract) = deloy_openmark_factory();

    let mut spy = spy_events(SpyOn::One(contract_address));

    factory_contract
        .create_collection(
            0, TEST_SELLER.try_into().unwrap(), "Starknet NFT", "Stark NFT", "https://starknet.io"
        );

    let nft_address = factory_contract.get_collection(0);

    let expected_event = FactoryEvent::CollectionCreated(
        CollectionCreated {
            id: 0,
            address: nft_address,
            owner: TEST_SELLER.try_into().unwrap(),
            name: "Starknet NFT",
            symbol: "Stark NFT",
            base_uri: "https://starknet.io"
        }
    );
    spy.assert_emitted(@array![(contract_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OMFactory: ID in use',))]
fn create_collection_id_used_panics() {
    let (_, factory_contract) = deloy_openmark_factory();

    factory_contract
        .create_collection(
            0, TEST_SELLER.try_into().unwrap(), "Starknet NFT", "Stark NFT", "https://starknet.io"
        );
    factory_contract
        .create_collection(
            0, TEST_SELLER.try_into().unwrap(), "Starknet", "Stark", "https://starknet.io"
        );
}
