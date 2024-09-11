#[starknet::contract]
pub mod Launchpad {
    use openzeppelin_utils::serde::SerializedAppend;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_merkle_tree::merkle_proof::{verify};
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use openzeppelin::utils::{try_selector_with_fallback};
    use openzeppelin::utils::UnwrapAndCast;
    use openzeppelin::utils::selectors;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::pedersen::{PedersenTrait, pedersen};

    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use starknet::SyscallResultTrait;
    use openmark::launchpad::interface::{ILaunchpad, ILaunchpadProvider};
    use openmark::primitives::types::{Stage, ID};
    use openmark::primitives::selectors as openmark_selectors;
    use openmark::launchpad::errors as Errors;
    use openmark::primitives::utils::{_safe_batch_mint, _payment_transfer_from};

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
        isClosed: bool,
        depositAmount: u128,
        launchpadStages: Map<ID, Stage>,
        isStageOn: Map<ID, bool>,
        stageWhitelist: Map<ID, Option<felt252>>,
        stageMintedCount: Map<ID, u128>,
        userMintedCount: Map<ContractAddress, Map<ID, u128>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn updateStages(
            ref self: ContractState, stages: Span<Stage>, merkleRoots: Span<Option<felt252>>
        ) {
            assert(stages.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let mut i = 0;
            while (i < stages.len()) {
                let stageId = *stages.at(i).id;
                self.isStageOn.write(stageId, true);
                self.launchpadStages.write(stageId, *stages.at(i));
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                i += 1;
            }
        }

        fn removeStages(ref self: ContractState, stageIds: Span<ID>) {
            for stageId in stageIds {
                assert(self.isStageOn.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.isStageOn.write(*stageId, false);
            };
        }

        fn updateWhitelist(
            ref self: ContractState, stageIds: Span<u128>, merkleRoots: Span<Option<felt252>>
        ) {
            assert(stageIds.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let mut i = 0;
            while (i < stageIds.len()) {
                let stageId = *stageIds.at(i);
                assert(self.isStageOn.read(stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                i += 1;
            }
        }

        fn removeWhitelist(ref self: ContractState, stageIds: Span<u128>) {
            for stageId in stageIds {
                assert(self.isStageOn.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(*stageId, Option::None);
            };
        }

        fn buy(ref self: ContractState, stageId: ID, amount: u32, merkleProof: Span<felt252>) {
            assert(!self.isClosed.read(), Errors::LAUNCHPAD_CLOSED);

            let minter: ContractAddress = get_caller_address();
            let mintAmount: u128 = amount.into();
            let stage = self.getActiveStage(stageId);

            assert(amount > 0, Errors::INVALID_MINT_AMOUNT);

            let stageMintedAmount = self.stageMintedCount.read(stageId);
            let userMintedAmount = self.userMintedCount.entry(minter).read(stageId);

            println!("Mint amount: {:?}", stageMintedAmount + mintAmount);
            println!("Max amount: {:?}", stage.maxAllocation);

            assert(stageMintedAmount + mintAmount <= stage.maxAllocation, Errors::SOLD_OUT);
            assert(userMintedAmount + mintAmount <= stage.limit, Errors::EXCEED_LIMIT);

            if let Option::Some(root) = self.getWhitelist(stageId) {
                assert(self.verifyWhitelist(root, merkleProof, minter), Errors::WHITELIST_FAILED);
            }

            let mintedTokens = _safe_batch_mint(stage.collection, minter, mintAmount.into());

            // let price = mintAmount * stage.price;

            // _payment_transfer_from(stage.payment, minter, get_contract_address(), price.into());

            self.stageMintedCount.write(stageId, stageMintedAmount + mintAmount);
            self.userMintedCount.entry(minter).entry(stageId).write(userMintedAmount + mintAmount);
        }

        fn withdrawSales(ref self: ContractState, tokens: Span<ContractAddress>) {}
    }

    #[abi(embed_v0)]
    impl LaunchpadProviderImpl of ILaunchpadProvider<ContractState> {
        fn getStage(self: @ContractState, stageId: ID) -> Stage {
            assert(self.isStageOn.read(stageId), Errors::STAGE_NOT_FOUND);
            return self.launchpadStages.read(stageId);
        }

        fn getActiveStage(self: @ContractState, stageId: ID) -> Stage {
            let stage = self.getStage(stageId);
            assert(_is_active_stage(stage.startTime, stage.endTime), Errors::STAGE_INACTIVE);
            return stage;
        }

        fn getWhitelist(self: @ContractState, stageId: ID) -> Option<felt252> {
            return self.stageWhitelist.read(stageId);
        }

        fn getMintedCount(self: @ContractState, stageId: ID) -> u128 {
            0
        }

        fn getUserMintedCount(self: @ContractState, minter: ContractAddress, stageId: ID) -> u128 {
            0
        }

        fn verifyWhitelist(
            self: @ContractState,
            merkleRoot: felt252,
            merkleProof: Span<felt252>,
            minter: ContractAddress
        ) -> bool {
            let leaf_hash = _leaf_hash(minter);
            return verify::<PedersenCHasher>(merkleProof, merkleRoot, leaf_hash);
        }
    }

    fn _leaf_hash(address: ContractAddress) -> felt252 {
        let hash_state = PedersenTrait::new(0);
        pedersen(0, hash_state.update_with(address).update_with(1).finalize())
    }

    fn _is_active_stage(startTime: u128, endTime: u128) -> bool {
        return startTime <= get_block_timestamp().into() && endTime >= get_block_timestamp().into();
    }
}
