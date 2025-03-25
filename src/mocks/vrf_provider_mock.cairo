// SPDX-License-Identifier: GPL-3.0
#[starknet::contract]
mod VRFProviderMock {
    use starknet::{ContractAddress, get_caller_address};
    use openmark::launchpad::interface::{IVrfProvider, Source};
    use core::num::traits::Zero;
    use starknet::storage::{Map};
    use core::array::{ArrayTrait};

    #[storage]
    struct Storage {
        // Tracks the number of times consume_random has been called for each (caller, source)
        call_count: Map<(ContractAddress, felt252), felt252>,
        // Tracks whether a random value has been requested but not yet consumed
        requested: Map<(ContractAddress, felt252), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(ref self: ContractState) {
        // No initialization needed, values start at 0
    }

    #[abi(embed_v0)]
    impl VrfProviderImpl of IVrfProvider<ContractState> {
        fn request_random(self: @ContractState, caller: ContractAddress, source: Source) {
            let source_key = match source {
                Source::Nonce(addr) => addr.into(),
                Source::Salt(salt) => salt,
            };
            // We can't write here, so just mark as requested if it hasn’t been consumed yet
            // Validation only; actual logic moves to consume_random
            assert(!self.requested.read((caller, source_key)), 'Random value already requested');
            // Note: We can't write self.requested here due to @ContractState, so we rely on consume_random to set it
        }

        fn consume_random(ref self: ContractState, source: Source) -> felt252 {
            let caller = get_caller_address();
            let source_key = match source {
                Source::Nonce(addr) => addr.into(),
                Source::Salt(salt) => salt,
            };
            let key = (caller, source_key);

            // Ensure request_random was called (we'll assume it’s called offchain in multicall)
            assert(!self.requested.read(key), 'Random value already consumed');

            // Get the current call count (starts at 0 if uninitialized)
            let call_count = self.call_count.read(key);
            let random_value = if call_count.is_zero() {
                100 // First call starts at 100
            } else {
                100 + call_count // Subsequent calls increment from 100
            };

            // Increment call count for next time
            self.call_count.write(key, call_count + 1);
            // Mark as requested (simulating request_random’s intent) and consumed
            self.requested.write(key, true); // Mark as requested
            self.requested.write(key, false); // Immediately mark as consumed

            random_value
        }
    }
}