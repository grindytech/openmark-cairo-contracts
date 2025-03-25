// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod StageVRF {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openmark::launchpad::stage::StageComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openmark::primitives::types::{Stage};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::launchpad::events::{TokensBought};
    use openmark::assets::interface::{IERC1155MinterDispatcher, IERC1155MinterDispatcherTrait};
    use core::array::{ArrayTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use openmark::launchpad::interface::{IStageVRF, DropEntry};
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address
    };
    component!(path: StageComponent, storage: ostage, event: OStageEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl OStageImpl = StageComponent::OStageImpl<ContractState>;
    impl OStageInternalImpl = StageComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[derive(Drop, Copy, Clone, Serde)]
    pub enum Source {
        Nonce: ContractAddress,
        Salt: felt252,
    }

    // VRF Interface Definition
    #[starknet::interface]
    trait IVrfProvider<TContractState> {
        fn request_random(self: @TContractState, caller: ContractAddress, source: Source);
        fn consume_random(ref self: TContractState, source: Source) -> felt252;
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ostage: StageComponent::Storage,
        // Drop table storage
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
        vrfProvider: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self
            .ostage
            .initializer(
                stage, rootWhitelist, collectionWhitelists, commission, commissionReceiver,
            );

        self.vrf_provider.write(vrfProvider);
    }

    #[abi(embed_v0)]
    impl StageVRFImpl of IStageVRF<ContractState> {
        fn setup(ref self: ContractState, drop_table: Span<DropEntry>) {
            // Initialize drop table
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
            // Validate stage
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

            // Initialize VRF Dispatcher
            let vrf_provider = IVrfProviderDispatcher {
                contract_address: self.vrf_provider.read(),
            };
            let random_value = vrf_provider.consume_random(Source::Nonce(minter));

            // Roll the drop table 'amount' times, 1 token per roll
            let mut tokenIds: Array<u256> = ArrayTrait::new();
            let mut values: Array<u256> = ArrayTrait::new();
            let total_weight = self.total_weight.read();
            let mut i: u256 = 0;

            while i < amount {
                // Map random value to a drop entry
                let roll = (random_value.into() + i) % total_weight.into();
                let mut cumulative_weight: u128 = 0;
                let mut j: u32 = 0;

                while j < self.drop_table_length.read() {
                    let entry = self.drop_table.read(j);
                    cumulative_weight += entry.weight;
                    if roll.into() < cumulative_weight.into() {
                        // Selected this entry, quantity is 1
                        tokenIds.append(entry.token_id);
                        values.append(1); // 1 token per roll
                        break;
                    }
                    j += 1;
                };
                i += 1;
            };

            // Update minted counts
            self.ostage.stageMintedCount.write(stageMintedAmount + amount);
            self.ostage.userMintedCount.write(minter, userMintedAmount + amount);

            // Mint the tokens
            let mint_dispatcher = IERC1155MinterDispatcher {
                contract_address: self.ostage.stage.collection.read(),
            };
            mint_dispatcher.mintBatch(minter, tokenIds.span(), values.span(), [].span());

            // Handle payment (price per roll/token)
            let price = amount * self.ostage.stage.price.read(); // Price per token dropped
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
