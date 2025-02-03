#[starknet::contract]
pub mod Launchpad {
    use openzeppelin_access::ownable::interface::IOwnable;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;

    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use starknet::{ClassHash, ContractAddress, get_caller_address, SyscallResultTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use openmark::launchpad::interface::{ILaunchpad};
    use openmark::primitives::types::{Stage, ID, StageType};
    use openmark::primitives::constants::{MINTER_ROLE, PERMYRIAD};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::primitives::utils::{access_has_role};

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
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
        // Mapping of payment tokens
        paymentTokens: Map<ContractAddress, bool>,
        // Stored maximum allowed sales duration
        maxSalesDuration: u128,
        selector_classhash: ClassHash,
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
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, paymentTokens: Span<ContractAddress>
    ) {
        self.ownable.initializer(owner);

        for token in paymentTokens {
            self.paymentTokens.write(*token, true);
        };

        self.commission.write(500); // per mille (default 5%)
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn createStage(ref self: ContractState, id: ID, stage: Stage) {
            self.ownable.assert_only_owner();
            let owner = get_caller_address();
            self.validateStage(stage, owner);

            if (stage.stageType == StageType::Selector) {
                let mut constructor_calldata = ArrayTrait::new();
                owner.serialize(ref constructor_calldata);
                stage.serialize(ref constructor_calldata);
                self.commission.read().serialize(ref constructor_calldata);
                self.ownable.owner().serialize(ref constructor_calldata);

                let (address, _) = core::starknet::syscalls::deploy_syscall(
                    self.selector_classhash.read(), 0, constructor_calldata.span(), false
                )
                    .unwrap_syscall();

                self.stages.write(id, address);
            }
        }

        fn validateStage(self: @ContractState, stage: Stage, owner: ContractAddress) {
            assert(stage.startTime < stage.endTime, Errors::INVALID_DURATION);

            assert(
                stage.endTime - stage.startTime < self.maxSalesDuration.read(),
                Errors::SALE_DURATION_EXCEEDED
            );

            assert(self.paymentTokens.read(stage.payment), Errors::INVALID_PAYMENT_TOKEN);

            assert(
                access_has_role(stage.collection, DEFAULT_ADMIN_ROLE, owner)
                    || access_has_role(stage.collection, MINTER_ROLE, owner),
                Errors::UNAUTHORIZED_OWNER
            );
        }
    }
}
