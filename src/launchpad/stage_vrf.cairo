// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod StageVRF {
    use core::num::traits::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openmark::launchpad::stage::StageComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openmark::primitives::types::{Stage, DropEntry};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::launchpad::events::{TokensBought};
    use openmark::assets::interface::{IERC1155MinterDispatcher, IERC1155MinterDispatcherTrait};
    use core::array::{ArrayTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use openmark::launchpad::interface::{
        IStageVRF, Source, IVrfProviderDispatcher, IVrfProviderDispatcherTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    use core::poseidon::{poseidon_hash_span};

    component!(path: StageComponent, storage: ostage, event: OStageEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OStageImpl = StageComponent::OStageImpl<ContractState>;
    impl OStageInternalImpl = StageComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ostage: StageComponent::Storage,
        drop_table: Map<u32, DropEntry>,
        drop_table_length: u32,
        total_weight: u128,
        vrf_provider: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OStageEvent: StageComponent::Event,
        TokensBought: TokensBought,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        stage: Stage,
        rootWhitelist: Option::<felt252>,
        collectionWhitelists: Span<ContractAddress>,
        commission: u128,
        commissionReceiver: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self
            .ostage
            .initializer(
                stage, rootWhitelist, collectionWhitelists, commission, commissionReceiver,
            );
    }

    // Internal function to generate a random roll value
    #[inline(always)]
    fn generate_roll(random_seed: felt252, index: u256, total_weight: u128) -> u256 {
        let mut hash_input: Array<felt252> = ArrayTrait::new();
        hash_input.append(random_seed);
        hash_input.append(index.try_into().unwrap());
        let roll_hash = poseidon_hash_span(hash_input.span());
        (roll_hash.into() % total_weight.into())
    }

    #[abi(embed_v0)]
    impl StageVRFImpl of IStageVRF<ContractState> {
        fn setup(
            ref self: ContractState, vrf_provider: ContractAddress, drop_table: Span<DropEntry>,
        ) {
            self.ownable.assert_only_owner();
            self.vrf_provider.write(vrf_provider);

            let mut total_weight: u128 = 0;
            let mut i: u32 = 0;
            for entry in drop_table {
                self.drop_table.write(i, *entry);
                total_weight += (*entry).weight;
                i += 1;
            };
            self.drop_table_length.write(i);
            self.total_weight.write(total_weight);
        }


        fn buy(ref self: ContractState, amount: u256, merkleProof: Span<felt252>) {
            self.validateStage();
            assert(amount > 0, Errors::ZERO_MINT_AMOUNT);

            let minter: ContractAddress = get_caller_address();
            let stageMintedAmount = self.ostage.stageMintedCount.read();
            let userMintedAmount = self.ostage.userMintedCount.read(minter);

            assert(
                stageMintedAmount + amount <= self.ostage.stage.maxAllocation.read(),
                Errors::SOLD_OUT,
            );
            assert(
                userMintedAmount + amount <= self.ostage.stage.limit.read(), Errors::EXCEED_LIMIT,
            );

            self.validateWhitelist(minter, merkleProof);

            let vrf_provider = IVrfProviderDispatcher {
                contract_address: self.vrf_provider.read(),
            };
            let random_seed = vrf_provider.consume_random(Source::Nonce(minter));

            let mut tokenIds: Array<u256> = ArrayTrait::new();
            let mut values: Array<u256> = ArrayTrait::new();
            let total_weight = self.total_weight.read();
            let mut i: u256 = 0;

            while i < amount {
                let roll = generate_roll(random_seed, i, total_weight);

                let mut cumulative_weight: u128 = 0;
                let mut j: u32 = 0;

                while j < self.drop_table_length.read() {
                    let entry = self.drop_table.read(j);
                    cumulative_weight += entry.weight;
                    if roll.into() < cumulative_weight.into() {
                        tokenIds.append(entry.token_id);
                        values.append(1);
                        break;
                    }
                    j += 1;
                };
                i += 1;
            };

            self.ostage.stageMintedCount.write(stageMintedAmount + amount);
            self.ostage.userMintedCount.write(minter, userMintedAmount + amount);

            let mint_dispatcher = IERC1155MinterDispatcher {
                contract_address: self.ostage.stage.collection.read(),
            };
            mint_dispatcher.mintBatch(minter, tokenIds.span(), values.span(), [].span());

            let price = amount * self.ostage.stage.price.read();
            let token_dispatcher = IERC20Dispatcher {
                contract_address: self.ostage.stage.payment.read(),
            };
            token_dispatcher.transfer_from(minter, get_contract_address(), price.into());

            self
                .emit(
                    TokensBought {
                        buyer: minter,
                        amount: amount.into(),
                        paymentToken: self.ostage.stage.payment.read(),
                        price: self.ostage.stage.price.read(),
                    },
                );
        }

        fn withdrawSales(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.ostage.withdrawSales(self.owner());
        }

        fn closeStage(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.ostage.closeStage();
        }
    }
}
