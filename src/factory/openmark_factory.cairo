#[starknet::contract]
pub mod OpenMarkFactory {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, get_caller_address};
    use openmark::token::interface::{IOpenMarkFactory, IOpenMarkFactoryCamel};

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
        factory: LegacyMap<u256, ContractAddress>,
        openmark_nft: ClassHash,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CollectionCreated {
        pub id: u256,
        pub address: ContractAddress,
        pub owner: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub base_uri: ByteArray,
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
    fn constructor(ref self: ContractState, owner: ContractAddress, openmark_nft: ClassHash) {
        self.ownable.initializer(owner);
        self.openmark_nft.write(openmark_nft);
    }

    #[abi(embed_v0)]
    impl OpenMarkFactoryImpl of IOpenMarkFactory<ContractState> {
        fn create_collection(
            ref self: ContractState,
            id: u256,
            owner: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            base_uri: ByteArray,
        ) {
            assert(self.get_collection(id).is_zero(), 'OMFactory: ID in use');

            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            name.serialize(ref constructor_calldata);
            symbol.serialize(ref constructor_calldata);
            base_uri.serialize(ref constructor_calldata);

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                self.openmark_nft.read(), 0, constructor_calldata.span(), false
            )
                .unwrap_syscall();

            self.factory.write(id, address);
            self.emit(CollectionCreated { id, address, owner, name, symbol, base_uri });
        }

        fn get_collection(self: @ContractState, id: u256) -> ContractAddress {
            self.factory.read(id)
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkFactoryCamelImpl of IOpenMarkFactoryCamel<ContractState> {
        fn createCollection(
            ref self: ContractState,
            id: u256,
            owner: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            baseURI: ByteArray,
        ) {
            self.create_collection(id, owner, name, symbol, baseURI);
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
    fn set_openmark_nft(ref self: ContractState, classhash: ClassHash) {
        self.ownable.assert_only_owner();
        self.openmark_nft.write(classhash);
    }
}
