#[starknet::contract]
pub mod Launchpad {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_merkle_tree::merkle_proof::{
        process_proof, process_multi_proof, verify, verify_multi_proof, verify_pedersen
    };
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher};

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait};
    use openmark::launchpad::interface::{ILaunchpad, ILaunchpadProvider};
    use openmark::primitives::types::{Stage};
    use openmark::launchpad::errors as Errors;

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
        launchpadStages: starknet::storage::Map<u128, Stage>,
        isStageOn: starknet::storage::Map<u128, bool>,
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
        fn updateStages(ref self: ContractState, stages: Span<Stage>, merkleRoots: Span<felt252>) {
            let mut i = 0;

            assert(stages.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            while (i < stages.len()) {
                self.isStageOn.write(*stages.at(i).id, true);
                self.launchpadStages.write(1_u128, *stages.at(i));
                i += 1;
            }
        }

        fn removeStages(ref self: ContractState, stageIds: Span<u128>) {}

        fn updateWhitelist(
            ref self: ContractState, stageIds: Span<u128>, merkleRoots: Span<felt252>
        ) {}

        fn removeWhitelist(ref self: ContractState, stageIds: Span<u128>) {}

        fn buy(ref self: ContractState, stageId: u128, amount: u32, merkleProof: Span<felt252>) {}

        fn withdrawSales(ref self: ContractState, tokens: Span<ContractAddress>) {}
    }

    #[abi(embed_v0)]
    impl LaunchpadProviderImpl of ILaunchpadProvider<ContractState> {
        fn getStage(self: @ContractState, stageId: u128) -> Stage {
            return self.launchpadStages.read(stageId);
        }

        fn getActiveStage(self: @ContractState, stageId: u128) -> Stage {
            return self.launchpadStages.read(stageId);
        }

        fn getWhitelist(self: @ContractState, stageId: u128) -> Option<felt252> {
            return Option::None;
        }
        fn getMintedCount(self: @ContractState, stageId: u128) -> u128 {
            0
        }
        fn getUserMintedCount(
            self: @ContractState, minter: ContractAddress, stageId: u128
        ) -> u128 {
            0
        }
        fn verifyWhitelist(
            self: @ContractState,
            merkleRoot: felt252,
            merkleProof: Span<felt252>,
            minter: ContractAddress
        ) -> bool {
            verify::<PedersenCHasher>(merkleProof, merkleRoot, minter.into())
        }
    }
}
