// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod OERC1155Factory {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use core::num::traits::Zero;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, get_caller_address};
    use openmark::factory::interface::{IOERC1155Factory, IFactoryManager};

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
        pub uri: ByteArray,
        pub max_token_id: u256,
        pub royalty_percentage: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CollectionCreated: CollectionCreated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, collection_classhash: ClassHash,
    ) {
        self.ownable.initializer(owner);
        self.collection_classhash.write(collection_classhash);
    }

    #[abi(embed_v0)]
    impl NFTFactoryImpl of IOERC1155Factory<ContractState> {
        fn createInstance(
            ref self: ContractState,
            id: u256,
            name: ByteArray,
            symbol: ByteArray,
            uri: ByteArray,
            max_token_id: u256,
            royalty_percentage: u256,
        ) {
            assert(self.factory.read(id).is_zero(), 'OM: ID in use');

            let owner = get_caller_address();
            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            name.serialize(ref constructor_calldata);
            symbol.serialize(ref constructor_calldata);
            uri.serialize(ref constructor_calldata);
            max_token_id.serialize(ref constructor_calldata);
            royalty_percentage.serialize(ref constructor_calldata);

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                self.collection_classhash.read(), 0, constructor_calldata.span(), false,
            )
                .unwrap_syscall();

            self.factory.write(id, address);
            self
                .emit(
                    CollectionCreated {
                        id, address, owner, name, symbol, uri, max_token_id, royalty_percentage,
                    },
                );
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
            self.collection_classhash.write(classhash);
        }
    }
}
