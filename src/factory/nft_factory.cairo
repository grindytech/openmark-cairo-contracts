#[starknet::contract]
pub mod NFTFactory {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait};
    use openmark::factory::interface::{INFTFactory, INFTFactoryCamel, INFTFactoryManager};

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
        factory: starknet::storage::Map<u256, ContractAddress>,
        collection_classhash: ClassHash,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CollectionCreated {
        pub id: u256,
        pub address: ContractAddress,
        pub owner: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub base_uri: ByteArray,
        pub total_supply: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CollectionCreated: CollectionCreated
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, collection_classhash: ClassHash) {
        self.ownable.initializer(owner);
        self.collection_classhash.write(collection_classhash);
    }

    #[abi(embed_v0)]
    impl NFTFactoryImpl of INFTFactory<ContractState> {
        fn create_collection(
            ref self: ContractState,
            id: u256,
            owner: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            base_uri: ByteArray,
            total_supply: u256
        ) {
            assert(self.get_collection(id).is_zero(), 'OMFactory: ID in use');

            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            name.serialize(ref constructor_calldata);
            symbol.serialize(ref constructor_calldata);
            base_uri.serialize(ref constructor_calldata);
            total_supply.serialize(ref constructor_calldata);

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                self.collection_classhash.read(), 0, constructor_calldata.span(), false
            )
                .unwrap_syscall();

            self.factory.write(id, address);
            self.emit(CollectionCreated { id, address, owner, name, symbol, base_uri, total_supply });
        }

        fn get_collection(self: @ContractState, id: u256) -> ContractAddress {
            self.factory.read(id)
        }
    }

    #[abi(embed_v0)]
    impl NFTFactoryCamelImpl of INFTFactoryCamel<ContractState> {
        fn createCollection(
            ref self: ContractState,
            id: u256,
            owner: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            baseURI: ByteArray,
            totalSupply: u256
        ) {
            self.create_collection(id, owner, name, symbol, baseURI, totalSupply);
        }

        fn getCollection(self: @ContractState, id: u256) -> ContractAddress {
            self.get_collection(id)
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
    impl FactoryManagerImpl of INFTFactoryManager<ContractState> {
        fn set_classhash(ref self: ContractState, classhash: ClassHash) {
            self.ownable.assert_only_owner();
            self.collection_classhash.write(classhash);
        }
    }
}
