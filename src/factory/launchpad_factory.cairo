// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod LaunchpadFactory {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait};
    use starknet::storage::{Map};
    use openmark::factory::interface::{ILaunchpadFactory, IFactoryManager};

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        factory: Map<u256, ContractAddress>,
        commission: u32,
        launchpad_classhash: ClassHash,
        selector_classhash: ClassHash,
        batch_selector_classhash: ClassHash,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct LaunchpadCreated {
        pub id: u256,
        pub address: ContractAddress,
        pub owner: ContractAddress,
        pub commission: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        LaunchpadCreated: LaunchpadCreated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        launchpad_classhash: ClassHash,
        commission: u32,
        selector_classhash: ClassHash,
        batch_selector_classhash: ClassHash,
    ) {
        self.ownable.initializer(owner);
        self.launchpad_classhash.write(launchpad_classhash);
        self.commission.write(commission);
        self.selector_classhash.write(selector_classhash);
        self.batch_selector_classhash.write(batch_selector_classhash);
    }

    #[abi(embed_v0)]
    impl LaunchpadFactoryImpl of ILaunchpadFactory<ContractState> {
        fn createInstance(ref self: ContractState, id: u256, owner: ContractAddress) {
            assert(self.factory.read(id).is_zero(), 'OM: ID in use');
            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            self.commission.read().serialize(ref constructor_calldata);
            self.ownable.owner().serialize(ref constructor_calldata); // commission receiver
            self.selector_classhash.read().serialize(ref constructor_calldata);
            self.batch_selector_classhash.read().serialize(ref constructor_calldata);

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                self.launchpad_classhash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap_syscall();
            self.factory.write(id, address);

            self.emit(LaunchpadCreated { id, address, owner, commission: self.commission.read() });
        }

        fn getInstance(self: @ContractState, id: u256) -> ContractAddress {
            self.factory.read(id)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl FactoryManagerImpl of IFactoryManager<ContractState> {
        fn set_classhash(ref self: ContractState, classhash: ClassHash) {
            self.ownable.assert_only_owner();
            self.launchpad_classhash.write(classhash);
        }
    }

     #[generate_trait]
    impl ExternalFunctions of ExternalFunctionsTrait {
        fn setCommission(ref self: ContractState, newCommission: u32) {
            self.ownable.assert_only_owner();
            self.commission.write(newCommission);
        }

        fn setSelectorClasshash(ref self: ContractState, newClasshash: ClassHash) {
            self.ownable.assert_only_owner();
            self.selector_classhash.write(newClasshash);
        }

        fn setBatchSelectorClasshash(ref self: ContractState, newClasshash: ClassHash) {
            self.ownable.assert_only_owner();
            self.batch_selector_classhash.write(newClasshash);
        }

        fn getConfig(self: @ContractState) -> (u32, ClassHash, ClassHash) {
            return (
                self.commission.read(),
                self.selector_classhash.read(),
                self.batch_selector_classhash.read(),
            );
        }
    }
}
