// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod StageFactory {
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
    use starknet::{
        ClassHash, ContractAddress, get_caller_address, SyscallResultTrait, contract_address_const,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use openmark::factory::interface::{IStageFactory};
    use openmark::primitives::types::{Stage, ID, StageType};
    use openmark::primitives::constants::{MINTER_ROLE};
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
        stage_selector: ClassHash,
        stage_batch_selector: ClassHash,
        stage_randomness: ClassHash,
        vrf_provider: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct StageCreated {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub stageId: ID,
        #[key]
        pub stageAddress: ContractAddress,
        pub stage: Stage,
        pub rootWhitelist: Option::<felt252>,
        pub collectionWhitelists: Span<ContractAddress>,
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
        stage_selector: ClassHash,
        stage_batch_selector: ClassHash,
        stage_randomness: ClassHash,
        vrf_provider: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.commission.write(commission);
        self.stage_selector.write(stage_selector);
        self.stage_batch_selector.write(stage_batch_selector);
        self.stage_randomness.write(stage_randomness);
        self.vrf_provider.write(vrf_provider);
    }

    #[abi(embed_v0)]
    impl StageFactoryImpl of IStageFactory<ContractState> {
        fn createInstance(
            ref self: ContractState,
            id: ID,
            stage: Stage,
            rootWhitelist: Option::<felt252>,
            collectionWhitelists: Span<ContractAddress>,
        ) {
            let owner = get_caller_address();

            assert(self.stages.read(id).is_zero(), 'OM: ID in use');
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
                    self.stage_selector.read(), id.into(), constructor_calldata.span(), false,
                )
                    .unwrap_syscall();

                self.stages.write(id, address);
                stageAddress = address;
            } else if (stage.stageType == StageType::BatchSelector) {
                let (address, _) = core::starknet::syscalls::deploy_syscall(
                    self.stage_batch_selector.read(), id.into(), constructor_calldata.span(), false,
                )
                    .unwrap_syscall();

                self.stages.write(id, address);
                stageAddress = address;
            } else if (stage.stageType == StageType::Randomness) {
                self.vrf_provider.read().serialize(ref constructor_calldata);
                let (address, _) = core::starknet::syscalls::deploy_syscall(
                    self.stage_randomness.read(), id.into(), constructor_calldata.span(), false,
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
            assert(stage.startTime < stage.endTime, 'OM: invalid duration');

            let access_dispatcher = IAccessControlDispatcher { contract_address: stage.collection };
            assert(
                access_dispatcher.has_role(DEFAULT_ADMIN_ROLE, owner)
                    || access_dispatcher.has_role(MINTER_ROLE, owner),
                'OM: unauthorized owner',
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
            self.stage_selector.write(newClasshash);
        }

        fn setBatchSelectorClasshash(ref self: ContractState, newClasshash: ClassHash) {
            self.ownable.assert_only_owner();
            self.stage_batch_selector.write(newClasshash);
        }

        fn setRandomnessClasshash(ref self: ContractState, newClasshash: ClassHash) {
            self.ownable.assert_only_owner();
            self.stage_batch_selector.write(newClasshash);
        }

        fn getConfig(self: @ContractState) -> (u32, ClassHash, ClassHash, ClassHash) {
            return (
                self.commission.read(),
                self.stage_selector.read(),
                self.stage_batch_selector.read(),
                self.stage_randomness.read(),
            );
        }
    }
}
