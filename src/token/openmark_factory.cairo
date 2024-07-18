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
        id: u256,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ContractDeployed {
        address: ContractAddress,
        deployer: ContractAddress,
        class_hash: ClassHash,
        calldata: Span<felt252>,
        salt: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        ContractDeployed: ContractDeployed
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.ownable.initializer(get_caller_address());
        self.id.write(0);
    }

    #[abi(embed_v0)]
    impl OpenMarkFactoryImpl of IOpenMarkFactory<ContractState> {
        fn deploy_contract(
            ref self: ContractState, class_hash: ClassHash, calldata: Span<felt252>, salt: felt252
        ) -> ContractAddress {
            let deployer: ContractAddress = get_caller_address();
            let mut _salt: felt252 = salt;

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                class_hash, _salt, calldata, false
            )
                .unwrap_syscall();
            let id = next_id(ref self);
            self.factory.write(id, address);
            self.emit(ContractDeployed { address, deployer, class_hash, calldata, salt });

            return address;
        }

        fn create_collection(
            ref self: ContractState,
            class_hash: ClassHash,
            salt: felt252,
            owner: felt252,
            name: felt252,
            symbol: felt252,
            base_uri: felt252,
        ) -> ContractAddress {
            let deployer: ContractAddress = get_caller_address();
            let mut _salt: felt252 = salt;

            let calldata: Span<felt252> = array![owner, name, symbol, base_uri].span();

            let (address, _) = core::starknet::syscalls::deploy_syscall(
                class_hash, _salt, calldata, false
            )
                .unwrap_syscall();
            let id = next_id(ref self);
            self.factory.write(id, address);
            self.emit(ContractDeployed { address, deployer, class_hash, calldata, salt });

            return address;
        }
    }


    /// Returns the current id and increments it for the next use.
    fn next_id(ref self: ContractState) -> u256 {
        let current_id = self.id.read();
        self.id.write(current_id + 1);
        current_id
    }
}

