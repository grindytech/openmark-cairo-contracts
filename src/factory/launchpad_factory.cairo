#[starknet::contract]
pub mod LaunchpadFactory {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait};
    use starknet::{get_caller_address, get_contract_address};
    use starknet::storage::{Map};
    use openmark::factory::interface::{
        ILaunchpadFactory, ILaunchpadFactoryCamel, ILaunchpadFactoryManager,
        ILaunchpadFactoryProvider
    };
    use openmark::primitives::types::{Balance};
    use openmark::primitives::utils::{payment_transfer_from};

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
        paymentTokens: Map<ContractAddress, bool>,
        lockAmount: Balance,
        lockTokenAddress: ContractAddress,
        launchpad_classhash: ClassHash,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct LaunchpadCreated {
        pub id: u256,
        pub address: ContractAddress,
        pub owner: ContractAddress,
        pub uri: ByteArray
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        LaunchpadCreated: LaunchpadCreated
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        lockAmount: Balance,
        lockTokenAddress: ContractAddress,
        paymentTokens: Span<ContractAddress>,
        launchpad_classhash: ClassHash,
    ) {
        self.ownable.initializer(owner);
        self.lockAmount.write(lockAmount);
        self.lockTokenAddress.write(lockTokenAddress);

        for paymentToken in paymentTokens {
            self.paymentTokens.write(*paymentToken, true);
        };

        self.launchpad_classhash.write(launchpad_classhash);
        self.commission.write(50); // default 5%
    }

    #[abi(embed_v0)]
    impl LaunchpadFactoryImpl of ILaunchpadFactory<ContractState> {
        fn create_launchpad(
            ref self: ContractState, id: u256, owner: ContractAddress, uri: ByteArray
        ) {
            assert(self.get_launchpad(id).is_zero(), 'OMFactory: ID in use');

            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            uri.serialize(ref constructor_calldata);
            self.lockAmount.read().serialize(ref constructor_calldata);
            self.lockTokenAddress.read().serialize(ref constructor_calldata);
            get_contract_address().serialize(ref constructor_calldata);

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                self.launchpad_classhash.read(), 0, constructor_calldata.span(), false
            )
                .unwrap_syscall();
            self.factory.write(id, address);

            payment_transfer_from(
                self.lockTokenAddress.read(),
                get_caller_address(),
                address,
                self.lockAmount.read().into()
            );

            self.emit(LaunchpadCreated { id, address, owner, uri });
        }

        fn get_launchpad(self: @ContractState, id: u256) -> ContractAddress {
            self.factory.read(id)
        }
    }

    #[abi(embed_v0)]
    impl LaunchpadFactoryCamelImpl of ILaunchpadFactoryCamel<ContractState> {
        fn createLaunchpad(
            ref self: ContractState, id: u256, owner: ContractAddress, uri: ByteArray,
        ) {
            self.create_launchpad(id, owner, uri);
        }
    }

    #[abi(embed_v0)]
    impl LaunchpadProviderImpl of ILaunchpadFactoryProvider<ContractState> {
        fn getLaunchpad(self: @ContractState, id: u256) -> ContractAddress {
            return self.get_launchpad(id);
        }

        fn getCommission(self: @ContractState,) -> u32 {
            return self.commission.read();
        }

        fn verifyPaymentToken(self: @ContractState, paymentToken: ContractAddress) -> bool {
            return self.paymentTokens.read(paymentToken);
        }

        fn getLaunchpadLockAmount(self: @ContractState,) -> Balance {
            return self.lockAmount.read();
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
    impl FactoryManagerImpl of ILaunchpadFactoryManager<ContractState> {
        fn set_classhash(ref self: ContractState, classhash: ClassHash) {
            self.ownable.assert_only_owner();
            self.launchpad_classhash.write(classhash);
        }
    }
}
