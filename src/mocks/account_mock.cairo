// Import Argent account interface
#[starknet::interface]
pub trait IAccount<T> {
    fn is_valid_signature(self: @T, hash: felt252, signature: Array<felt252>) -> felt252;
}

#[starknet::contract]
pub(crate) mod AccountMock {
    use starknet::{VALIDATED};
    use openzeppelin::introspection::src5::SRC5Component;
    use super::IAccount;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // SCR5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[abi(embed_v0)]
    impl Account of IAccount<ContractState> {
        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            VALIDATED
        }
    }
}
