use snforge_std::EventSpyAssertionsTrait;
use openmark::factory::interface::{ILaunchpadFactoryDispatcher, ILaunchpadFactoryDispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait, get_class_hash, DeclareResultTrait, spy_events};
use starknet::{ContractAddress, ClassHash};

use openmark::tests::unit::common::{SELLER1, toAddress, create_stage, ZERO};
use openmark::primitives::types::{StageType};
use openmark::launchpad::interface::{
    ILaunchpadProviderDispatcher, ILaunchpadProviderDispatcherTrait,
};
use openmark::factory::launchpad_factory::LaunchpadFactory;
use openmark::factory::launchpad_factory::LaunchpadFactory::LaunchpadCreated;

fn create_launchpad_template() -> ContractAddress {
    let contract = declare("Launchpad").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(toAddress(SELLER1));
    constructor_calldata.append_serde(0_u128);
    constructor_calldata.append_serde(toAddress(SELLER1));
    constructor_calldata.append_serde(0);
    constructor_calldata.append_serde(0);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    return contract_address;
}


pub fn create_launchpad_factory(
    owner: ContractAddress,
) -> (ContractAddress, ILaunchpadFactoryDispatcher, ClassHash, ClassHash) {
    let launchpad = create_launchpad_template();
    let launchpad_classhash = get_class_hash(launchpad);

    let selector = create_stage(
        StageType::BatchSelector, owner, ZERO(), ZERO(), Option::None, [].span(), 0, owner,
    );
    let batchSelector = create_stage(
        StageType::BatchSelector, owner, ZERO(), ZERO(), Option::None, [].span(), 0, owner,
    );
    let selector_classhash = get_class_hash(selector);
    let batch_selector_classhash = get_class_hash(batchSelector);

    let contract = declare("LaunchpadFactory").unwrap().contract_class();

    let mut constructor_calldata = array![];

    constructor_calldata.append_serde(owner);
    constructor_calldata.append_serde(launchpad_classhash);
    constructor_calldata.append_serde(0);
    constructor_calldata.append_serde(selector_classhash);
    constructor_calldata.append_serde(batch_selector_classhash);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (
        contract_address,
        ILaunchpadFactoryDispatcher { contract_address },
        selector_classhash,
        batch_selector_classhash,
    )
}


#[test]
fn create_launchpad_works() {
    let (factory_address, factory_contract, selector_classhash, batch_selector_classhash) =
        create_launchpad_factory(
        toAddress(SELLER1),
    );

    let mut spy = spy_events();
    factory_contract.createInstance(10, toAddress(SELLER1));
    let launchpad_address = factory_contract.getInstance(10);
    
    let expected_event = LaunchpadFactory::Event::LaunchpadCreated(LaunchpadCreated { id: 10, address: launchpad_address, owner: toAddress(SELLER1), commission: 0 });
    spy.assert_emitted(@array![(factory_address, expected_event)]);

    let launchpad_dispatcher = ILaunchpadProviderDispatcher { contract_address: launchpad_address };

    let config = launchpad_dispatcher.getConfig();
    assert(config == (0, selector_classhash, batch_selector_classhash), 'Create launchpd failed');
}


#[test]
#[should_panic(expected: ('OM: ID in use',))]
fn create_launchpad_id_used_panics() {
    let (_, factory_contract, _, _) = create_launchpad_factory(toAddress(SELLER1));
    factory_contract.createInstance(10, toAddress(SELLER1));
    factory_contract.createInstance(10, toAddress(SELLER1));
}

