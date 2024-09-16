#[starknet::contract]
pub mod Launchpad {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_merkle_tree::merkle_proof::{verify};
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::pedersen::{PedersenTrait, pedersen};

    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use openmark::launchpad::interface::{ILaunchpad, ILaunchpadProvider};
    use openmark::launchpad::events::{
        StageUpdated, StageRemoved, WhitelistUpdated, WhitelistRemoved, SalesWithdrawn,
        TokensBought, LaunchpadClosed
    };
    use openmark::primitives::types::{Stage, ID};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::primitives::utils::{
        nft_safe_batch_mint, payment_transfer_from, payment_transfer, payment_balance_of
    };

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

        StageUpdated: StageUpdated,
        StageRemoved: StageRemoved,
        WhitelistUpdated: WhitelistUpdated,
        WhitelistRemoved: WhitelistRemoved,
        SalesWithdrawn: SalesWithdrawn,
        TokensBought: TokensBought,
        LaunchpadClosed: LaunchpadClosed,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.isClosed.write(false);
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn updateStages(
            ref self: ContractState, stages: Span<Stage>, merkleRoots: Span<Option<felt252>>
        ) {
            self.ownable.assert_only_owner();
            assert(stages.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let mut i = 0;
            while (i < stages.len()) {
                let stageId = *stages.at(i).id;
                self.isStageOn.write(stageId, true);
                self.launchpadStages.write(stageId, *stages.at(i));
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                self
                    .emit(
                        StageUpdated {
                            owner: get_caller_address(),
                            stage: *stages.at(i),
                            merkleRoot: *merkleRoots.at(i)
                        }
                    );

                i += 1;
            }
        }

        fn removeStages(ref self: ContractState, stageIds: Span<ID>) {
            self.ownable.assert_only_owner();
            for stageId in stageIds {
                assert(self.isStageOn.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.isStageOn.write(*stageId, false);
                self.emit(StageRemoved { stageId: *stageId, });
            };
        }

        fn updateWhitelist(
            ref self: ContractState, stageIds: Span<u128>, merkleRoots: Span<Option<felt252>>
        ) {
            self.ownable.assert_only_owner();
            assert(stageIds.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);
            let mut i = 0;
            while (i < stageIds.len()) {
                let stageId = *stageIds.at(i);
                assert(self.isStageOn.read(stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                self.emit(WhitelistUpdated { stageId, merkleRoot: *merkleRoots.at(i) });
                i += 1;
            }
        }

        fn removeWhitelist(ref self: ContractState, stageIds: Span<u128>) {
            self.ownable.assert_only_owner();
            for stageId in stageIds {
                assert(self.isStageOn.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(*stageId, Option::None);
                self.emit(WhitelistRemoved { stageId: *stageId, });
            };
        }

        fn buy(ref self: ContractState, stageId: ID, amount: u128, merkleProof: Span<felt252>) {
            assert(!self.isClosed.read(), Errors::LAUNCHPAD_CLOSED);

            let minter: ContractAddress = get_caller_address();
            let mintAmount: u128 = amount.into();
            let stage = self.getActiveStage(stageId);

            assert(amount > 0, Errors::INVALID_MINT_AMOUNT);

            let stageMintedAmount = self.stageMintedCount.read(stageId);
            let userMintedAmount = self.userMintedCount.entry(minter).read(stageId);

            assert(stageMintedAmount + mintAmount <= stage.maxAllocation, Errors::SOLD_OUT);
            assert(userMintedAmount + mintAmount <= stage.limit, Errors::EXCEED_LIMIT);

            if let Option::Some(root) = self.getWhitelist(stageId) {
                assert(self.verifyWhitelist(root, merkleProof, minter), Errors::WHITELIST_FAILED);
            }

            let mintedTokens = nft_safe_batch_mint(stage.collection, minter, mintAmount.into());

            let price = mintAmount * stage.price;
            payment_transfer_from(stage.payment, minter, get_contract_address(), price.into());

            self.stageMintedCount.write(stageId, stageMintedAmount + mintAmount);
            self.userMintedCount.entry(minter).entry(stageId).write(userMintedAmount + mintAmount);

            self
                .emit(
                    TokensBought {
                        buyer: minter,
                        stageId,
                        amount,
                        paymentToken: stage.payment,
                        price: stage.price,
                        mintedTokens
                    }
                );
        }

        fn withdrawSales(ref self: ContractState, tokens: Span<ContractAddress>) {
            self.ownable.assert_only_owner();

            let owner = get_caller_address();
            let launchpad = get_contract_address();
            for token in tokens {
                let balance = payment_balance_of(*token, launchpad);
                payment_transfer(*token, owner, balance);
                self
                    .emit(
                        SalesWithdrawn {
                            owner, tokenPayment: *token, amount: balance.try_into().unwrap()
                        }
                    );
            };
        }
        
        fn closeLaunchpad(ref self: ContractState, tokens: Span<ContractAddress>) {
            self.ownable.assert_only_owner();
            self.isClosed.write(true);
            self.withdrawSales(tokens);
        }
    }

    #[abi(embed_v0)]
    impl LaunchpadProviderImpl of ILaunchpadProvider<ContractState> {
        fn getStage(self: @ContractState, stageId: ID) -> Stage {
            assert(self.isStageOn.read(stageId), Errors::STAGE_NOT_FOUND);
            return self.launchpadStages.read(stageId);
        }

        fn getActiveStage(self: @ContractState, stageId: ID) -> Stage {
            let stage = self.getStage(stageId);
            let currentTimestamp = get_block_timestamp().into();

            assert(currentTimestamp >= stage.startTime, Errors::STAGE_NOT_STARTED);
            assert(currentTimestamp <= stage.endTime, Errors::STAGE_ENDED);
            return stage;
        }

        fn getWhitelist(self: @ContractState, stageId: ID) -> Option<felt252> {
            return self.stageWhitelist.read(stageId);
        }

        fn getMintedCount(self: @ContractState, stageId: ID) -> u128 {
            return self.stageMintedCount.read(stageId);
        }

        fn getUserMintedCount(self: @ContractState, minter: ContractAddress, stageId: ID) -> u128 {
            return self.userMintedCount.entry(minter).read(stageId);
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

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
