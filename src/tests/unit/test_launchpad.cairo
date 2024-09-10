use openmark::factory::interface::INFTFactoryDispatcherTrait;
use core::option::OptionTrait;
use core::traits::TryInto;
use openmark::launchpad::interface::{ILaunchpadDispatcher};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{
    declare, ContractClassTrait,get_class_hash,
};
use starknet::{ContractAddress};

fn create_launchpad(owner: ContractAddress) -> (ContractAddress, ILaunchpadDispatcher) {
    let contract = declare("Launchpad").unwrap();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(owner);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, ILaunchpadDispatcher { contract_address })
}
