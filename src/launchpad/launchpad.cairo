#[starknet::contract]
pub mod Launchpad {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, storage::Map};

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
        launchpadStages: Map<u128, Stages>,
        isStageOn: Map<u128, bool>,
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
        fn updateStages(ref self: T, stages: Span<Stage>, merkleRoots: Span<felt252>) {
            let mut i = 0;

            assert(stages.len() == merkleRoots.len(), "mismatch length");
            
            while (i < stages.len()) {
                self.launchpadStages.write(stages[i].id, stages[i]);
                self.launchpadStages.write(stages[i].id, stages[i]);

                i += 1;
            }
        }

        fn removeStages(stageIds: Span<u128>) {}

        fn updateWhitelist(stageIds: Span<u128>, merkleRoots: Span<felt252>) {}

        fn removeWhitelist(stageIds: Span<u128>) {}

        fn buy(stageId: u128, amount: u32, merkleProof: Span<felt252>) {}

        fn withdrawSales(tokens: Span<ContractAddress>) {}
    }
}
