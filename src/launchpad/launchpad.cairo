#[starknet::contract]
pub mod Launchpad {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_merkle_tree::merkle_proof::{verify};
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};

    use core::num::traits::Zero;

    use starknet::{storage::Map, ClassHash, ContractAddress, get_block_timestamp};
    use openmark::launchpad::interface::{ILaunchpad, ILaunchpadProvider};
    use openmark::primitives::types::{Stage, ID};
    use openmark::launchpad::errors as Errors;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::pedersen::{PedersenTrait, pedersen};

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
        isClosed: bool,
        depositAmount: u128,
        launchpadStages: Map<ID, Stage>,
        isStageOn: Map<ID, bool>,
        stageWhitelist: Map<ID, Option<felt252>>,
        stageMintedCount: Map<ID, u128>,
        userMintedCount: Map<ContractAddress, Map<ID, u128>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn updateStages(
            ref self: ContractState, stages: Span<Stage>, merkleRoots: Span<Option<felt252>>
        ) {
            assert(stages.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let mut i = 0;
            while (i < stages.len()) {
                self.isStageOn.write(*stages.at(i).id, true);
                self.launchpadStages.write(1_u128, *stages.at(i));
                self.stageWhitelist.write(*stages.at(i).id, *merkleRoots.at(i));
                i += 1;
            }
        }

        fn removeStages(ref self: ContractState, stageIds: Span<ID>) {
            for stageId in stageIds {
                assert(self.isStageOn.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.isStageOn.write(*stageId, false);
            };
        }

        fn updateWhitelist(
            ref self: ContractState, stageIds: Span<u128>, merkleRoots: Span<Option<felt252>>
        ) {
            assert(stageIds.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let mut i = 0;
            while (i < stageIds.len()) {
                let stageId = *stageIds.at(i);
                assert(self.isStageOn.read(stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                i += 1;
            }
        }

        fn removeWhitelist(ref self: ContractState, stageIds: Span<u128>) {
            for stageId in stageIds {
                assert(self.isStageOn.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(*stageId, Option::None);
            };
        }

        fn buy(ref self: ContractState, stageId: ID, amount: u32, merkleProof: Span<felt252>) {}

        fn withdrawSales(ref self: ContractState, tokens: Span<ContractAddress>) {}
    }

    #[abi(embed_v0)]
    impl LaunchpadProviderImpl of ILaunchpadProvider<ContractState> {
        fn getStage(self: @ContractState, stageId: ID) -> Stage {
            assert(self.isStageOn.read(stageId), Errors::STAGE_NOT_FOUND);
            return self.launchpadStages.read(stageId);
        }

        fn getActiveStage(self: @ContractState, stageId: ID) -> Stage {
            let stage = self.getStage(stageId);
            assert(_is_active_stage(stage.startTime, stage.endTime), Errors::STAGE_INACTIVE);
            return stage;
        }

        fn getWhitelist(self: @ContractState, stageId: ID) -> Option<felt252> {
            return self.stageWhitelist.read(stageId);
        }

        fn getMintedCount(self: @ContractState, stageId: ID) -> u128 {
            0
        }

        fn getUserMintedCount(self: @ContractState, minter: ContractAddress, stageId: ID) -> u128 {
            0
        }

        fn verifyWhitelist(
            self: @ContractState,
            merkleRoot: felt252,
            merkleProof: Span<felt252>,
            minter: ContractAddress
        ) -> bool {
            let leaf_hash = _leaf_hash(minter);
            return verify::<PedersenCHasher>(merkleProof, merkleRoot, leaf_hash);
        }
    }

    fn _leaf_hash(address: ContractAddress) -> felt252 {
        let hash_state = PedersenTrait::new(0);
        pedersen(0, hash_state.update_with(address).update_with(1).finalize())
    }

    fn _is_active_stage(startTime: u128, endTime: u128) -> bool {
        return startTime <= get_block_timestamp().into() && endTime >= get_block_timestamp().into();
    }
}
