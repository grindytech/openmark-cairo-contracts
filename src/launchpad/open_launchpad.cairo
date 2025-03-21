// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod OpenLaunchpad {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::interface::IOwnable;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use starknet::{ClassHash, ContractAddress, get_caller_address, SyscallResultTrait, contract_address_const};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use openmark::launchpad::interface::{ILaunchpad};
    use openmark::primitives::types::{Stage, ID, StageType};
    use openmark::primitives::constants::{MINTER_ROLE};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::launchpad::events::StageCreated;
    use openzeppelin::upgrades::interface::IUpgradeable;

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    /// Reentrancy
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Mapping of all stages by ID
        stages: Map<ID, ContractAddress>,
        // Store sales commission
        commission: u32,
        selector_classhash: ClassHash,
        batch_selector_classhash: ClassHash,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        StageCreated: StageCreated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        commission: u32,
        selector_classhash: ClassHash,
        batch_selector_classhash: ClassHash,
    ) {
        self.ownable.initializer(owner);
        self.commission.write(commission); // per mille (default 5%)
        self.selector_classhash.write(selector_classhash);
        self.batch_selector_classhash.write(batch_selector_classhash);
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn createStage(
            ref self: ContractState,
            id: ID,
            stage: Stage,
            rootWhitelist: Option::<felt252>,
            collectionWhitelists: Span<ContractAddress>,
        ) {
            let owner = get_caller_address();

            assert(self.stages.read(id).is_zero(), Errors::STAGE_ID_USED);
            self.validateStage(stage, owner);

            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            stage.serialize(ref constructor_calldata);
            rootWhitelist.serialize(ref constructor_calldata);
            collectionWhitelists.serialize(ref constructor_calldata);
            self.commission.read().serialize(ref constructor_calldata);
            self.ownable.owner().serialize(ref constructor_calldata);

            let mut stageAddress = contract_address_const::<0>();
            if (stage.stageType == StageType::Selector) {
                let (address, _) = core::starknet::syscalls::deploy_syscall(
                    self.selector_classhash.read(), 0, constructor_calldata.span(), false,
                )
                    .unwrap_syscall();

                self.stages.write(id, address);
                stageAddress = address;
            } else if (stage.stageType == StageType::BatchSelector) {
                let (address, _) = core::starknet::syscalls::deploy_syscall(
                    self.batch_selector_classhash.read(), 0, constructor_calldata.span(), false,
                )
                    .unwrap_syscall();

                self.stages.write(id, address);
                stageAddress = address;
            }

            self
                .emit(
                    StageCreated {
                        owner,
                        stageId: id,
                        stageAddress: stageAddress,
                        stage,
                        rootWhitelist,
                        collectionWhitelists,
                    },
                );
        }

        fn validateStage(self: @ContractState, stage: Stage, owner: ContractAddress) {
            assert(stage.startTime < stage.endTime, Errors::INVALID_DURATION);

            let access_dispatcher = IAccessControlDispatcher { contract_address: stage.collection };
            assert(
                access_dispatcher.has_role(DEFAULT_ADMIN_ROLE, owner)
                    || access_dispatcher.has_role(MINTER_ROLE, owner),
                Errors::UNAUTHORIZED_OWNER,
            );
        }

        fn getStage(self: @ContractState, id: ID) -> ContractAddress {
            return self.stages.read(id);
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
