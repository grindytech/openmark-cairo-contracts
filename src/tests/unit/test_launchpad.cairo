use super::super::super::launchpad::interface::ILaunchpadDispatcherTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use openmark::launchpad::interface::{
    ILaunchpadDispatcher, ILaunchpadProviderDispatcherTrait, ILaunchpadProviderDispatcher,
};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait};
use starknet::{ContractAddress};
use openmark::tests::unit::common::{SELLER1, BUYER1, TEST_NFT, TEST_PAYMENT, toAddress, ZERO_HASH};
use openmark::primitives::types::{Stage};

fn create_launchpad(owner: ContractAddress) -> (ContractAddress, ILaunchpadDispatcher) {
    let contract = declare("Launchpad").unwrap();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(owner);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, ILaunchpadDispatcher { contract_address })
}

const ROOT: felt252 = 0x019ac32f9b02dfc6716b6a63ec196f97531fa1593175a9ab8d282a48e0bcb9bc;

const PROOF: [
    felt252
    ; 2] = [
    0x0457244b25dd29313d580c78c9fc5329621845ccbd2b1097bb06da473859ea74,
    0x04d84ae65560d8e8d1bb6783c1a56a192f364ea04c54669c79bdfb1ee9dbc256
];

#[test]
fn update_stages_works() {
    let owner = toAddress(SELLER1);
    let (contract_address, launchpad_contract) = create_launchpad(owner);

    let new_stages = array![
        Stage {
            id: 0,
            collection: toAddress(TEST_NFT),
            payment: toAddress(TEST_PAYMENT),
            price: 1,
            maxAllocation: 10,
            limit: 1,
            startTime: 0,
            endTime: 0,
        }
    ];

    // const root: felt252 = 1.try_into().unwrap();
    let whitelists = array![ZERO_HASH()];

    launchpad_contract.updateStages(new_stages.span(), whitelists.span());
    let provider = ILaunchpadProviderDispatcher { contract_address };
    assert_eq!(provider.getStage(0).id, 0);
    assert_eq!(provider.getActiveStage(0).id, 0);
}

#[test]
fn verify_whitelist_works() {
    let owner = toAddress(SELLER1);

    let (contract_address, launchpad_contract) = create_launchpad(owner);
    let provider = ILaunchpadProviderDispatcher { contract_address };

    assert!(provider.verifyWhitelist(ROOT, PROOF.span(), toAddress(BUYER1)));
}
