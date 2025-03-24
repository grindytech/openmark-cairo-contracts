use snforge_std::EventSpyAssertionsTrait;
use openmark::factory::interface::{IOERC1155FactoryDispatcher, IOERC1155FactoryDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait, get_class_hash, start_cheat_caller_address, DeclareResultTrait,
    spy_events,
};
use starknet::{ContractAddress};

use openmark::factory::oerc1155_factory::OERC1155Factory;
use openmark::factory::oerc1155_factory::OERC1155Factory::CollectionCreated;

use openmark::tests::unit::common::{create_test_oerc721, SELLER1, toAddress};

fn create_nft_factory() -> (ContractAddress, IOERC1155FactoryDispatcher) {
    let nft_token = create_test_oerc721();
    let nft_classhash = get_class_hash(nft_token);

    let contract = declare("OERC1155Factory").unwrap().contract_class();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(nft_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, IOERC1155FactoryDispatcher { contract_address })
}

#[test]
fn create_collection_works() {
    let (factory_address, factory_contract) = create_nft_factory();

    let mut spy = spy_events();
    start_cheat_caller_address(factory_address, toAddress(SELLER1));

    factory_contract
        .createInstance(0, "Starknet NFT", "Stark NFT", "https://starknet.io", 1000_u256, 0_u256);

    let nft_address = factory_contract.getInstance(0);

    let expected_event = OERC1155Factory::Event::CollectionCreated(
        CollectionCreated {
            id: 0,
            address: nft_address,
            owner: toAddress(SELLER1),
            name: "Starknet NFT",
            symbol: "Stark NFT",
            uri: "https://starknet.io",
            max_token_id: 1000_u256,
            royalty_percentage: 0_u256,
        },
    );

    spy.assert_emitted(@array![(factory_address, expected_event)]);
}

#[test]
#[should_panic(expected: ('OM: ID in use',))]
fn create_collection_id_used_panics() {
    let (_, factory_contract) = create_nft_factory();

    factory_contract
        .createInstance(0, "Starknet NFT", "Stark NFT", "https://starknet.io", 1000_u256, 0_u256);

    factory_contract
        .createInstance(0, "Starknet", "Stark", "https://starknet.io", 1000_u256, 0_u256);
}
