#[starknet::contract]
mod OpenMarkFactory {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::utils::serde::SerializedAppend;

    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, get_caller_address};
    use openmark::token::interface::IOpenMarkFactory;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        factory: LegacyMap<u256, ContractAddress>,
        contract_index: u256,
        openmark_nft: ClassHash,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct CollectionCreated {
        id: u256,
        address: ContractAddress,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        CollectionCreated: CollectionCreated
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, openmark_nft: ClassHash) {
        self.ownable.initializer(owner);
        self.openmark_nft.write(openmark_nft);
        self.contract_index.write(0);
    }

    #[abi(embed_v0)]
    impl OpenMarkFactoryImpl of IOpenMarkFactory<ContractState> {
        fn create_collection(
            ref self: ContractState,
            owner: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            base_uri: ByteArray,
        ) {
            let mut constructor_calldata = ArrayTrait::new();
            owner.serialize(ref constructor_calldata);
            name.serialize(ref constructor_calldata);
            symbol.serialize(ref constructor_calldata);
            base_uri.serialize(ref constructor_calldata);

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                self.openmark_nft.read(), 0, constructor_calldata.span(), false
            )
                .unwrap_syscall();

            let id = next_id(ref self);
            self.factory.write(id, address);
            self.emit(CollectionCreated { id, address, owner, name, symbol, base_uri });
        }

        fn set_openmark_nft(ref self: ContractState, classhash: ClassHash) {
            self.ownable.assert_only_owner();
            self.openmark_nft.write(classhash);
        }
    }


    /// Returns the current id and increments it for the next use.
    fn next_id(ref self: ContractState) -> u256 {
        let current_id = self.contract_index.read();
        self.contract_index.write(current_id + 1);
        current_id
    }
}

