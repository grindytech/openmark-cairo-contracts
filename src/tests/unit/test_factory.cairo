use openmark::factory::interface::{
    INFTFactoryDispatcher, INFTFactoryDispatcherTrait, ILaunchpadFactoryDispatcher,
    ILaunchpadFactoryDispatcherTrait,
};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    declare, ContractClassTrait, get_class_hash, start_cheat_caller_address,
    stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait, DeclareResultTrait
};
use starknet::{ContractAddress};

use openmark::factory::nft_factory::NFTFactory::Event as NFTEvents;
use openmark::factory::nft_factory::NFTFactory::CollectionCreated;

use openmark::factory::launchpad_factory::LaunchpadFactory::Event as LaunchpadEvents;
use openmark::factory::launchpad_factory::LaunchpadFactory::LaunchpadCreated;
use openmark::tests::unit::common::{
    create_openmark_nft, SELLER1, TEST_PAYMENT, setup_balance_at, toAddress,
    create_launchpad_factory
};

fn create_nft_factory() -> (ContractAddress, INFTFactoryDispatcher) {
    let nft_token = create_openmark_nft();
    let nft_classhash = get_class_hash(nft_token);

    let contract = declare("NFTFactory").unwrap().contract_class();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(SELLER1);
    constructor_calldata.append_serde(nft_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, INFTFactoryDispatcher { contract_address })
}

#[test]
fn create_collection_works() {
    let (_contract_address, factory_contract) = create_nft_factory();

    factory_contract
        .create_collection(
            0, toAddress(SELLER1), "Starknet NFT", "Stark NFT", "https://starknet.io", 1000_u256
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
        }
    );
}

#[test]
#[should_panic(expected: ('OMFactory: ID in use',))]
fn create_collection_id_used_panics() {
    let (_, factory_contract) = create_nft_factory();

    factory_contract
        .create_collection(
            0, toAddress(SELLER1), "Starknet NFT", "Stark NFT", "https://starknet.io", 1000_u256
        );
    factory_contract
        .create_collection(
            0, toAddress(SELLER1), "Starknet", "Stark", "https://starknet.io", 1000_u256
        );
}

#[test]
fn create_factory_works() {
    let owner = toAddress(SELLER1);
    let lockAmount = 1000_u128;
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));

    let lockPaymentTokens = array![payment_token].span();

    let (factory_address, factory_contract) = create_launchpad_factory(
        owner, lockAmount, payment_token, lockPaymentTokens
    );

    let erc20_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    start_cheat_caller_address(payment_token, owner);
    erc20_dispatcher.approve(factory_address, 10000000);
    stop_cheat_caller_address(payment_token);

    let owner_balance = erc20_dispatcher.balance_of(owner);
    start_cheat_caller_address(factory_address, owner);
    let mut spy = spy_events();

    factory_contract.create_launchpad(0, toAddress(SELLER1), "https://starknet.io");

    let provider_dispatcher = ILaunchpadFactoryDispatcher { contract_address: factory_address };
    let launchpad_address = provider_dispatcher.get_launchpad(0);

    let expected_event = LaunchpadEvents::LaunchpadCreated(
        LaunchpadCreated {
            id: 0, address: launchpad_address, owner: toAddress(SELLER1), uri: "https://starknet.io"
        }
    );
    spy.assert_emitted(@array![(factory_address, expected_event)]);

    assert(
        erc20_dispatcher.balance_of(owner) == owner_balance - lockAmount.into(),
        'owner balance not correct'
    );

    assert(
        erc20_dispatcher.balance_of(launchpad_address) == lockAmount.into(),
        'launchpad balance not correct'
    );
}

#[test]
#[should_panic(expected: ('OMFactory: ID in use',))]
fn create_launchpad_id_used_panics() {
    let owner = toAddress(SELLER1);
    let lockAmount = 1000_u128;
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));

    let lockPaymentTokens = array![payment_token].span();

    let (factory_address, factory_contract) = create_launchpad_factory(
        owner, lockAmount, payment_token, lockPaymentTokens
    );

    let erc20_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    start_cheat_caller_address(payment_token, owner);
    erc20_dispatcher.approve(factory_address, 10000000);
    stop_cheat_caller_address(payment_token);
    start_cheat_caller_address(factory_address, owner);

    factory_contract.create_launchpad(0, toAddress(SELLER1), "https://starknet.io");
    factory_contract.create_launchpad(0, toAddress(SELLER1), "https://starknet.io");
}
