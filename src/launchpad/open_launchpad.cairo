#[starknet::contract]
pub mod OpenLaunchpad {
    use openzeppelin_access::ownable::interface::IOwnable;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::upgrades::UpgradeableComponent;

    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_merkle_tree::merkle_proof::{verify};
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::pedersen::{PedersenTrait, pedersen};

    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use openmark::launchpad::interface::{
        ILaunchpad, ILaunchpadProvider, IOpenLaunchpadManager, IOpenLaunchpadProvider
    };
    use openmark::launchpad::events::{
        StageUpdated, StageRemoved, WhitelistUpdated, WhitelistRemoved, SalesWithdrawn,
        TokensBought, LaunchpadClosed
    };
    use openmark::primitives::types::{Stage, ID, Balance};
    use openmark::primitives::constants::{MINTER_ROLE, PERMYRIAD};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::primitives::utils::{
        nft_safe_batch_mint, payment_transfer_from, payment_transfer, access_has_role
    };

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
    );

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    /// Reentrancy
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Mapping of all stages by ID
        stages: Map<ID, Stage>,
        // Mapping to indicate if a stage is in used
        stageId: Map<ID, bool>,
        // Mapping of owner of stage by ID
        stageOwner: Map<ID, ContractAddress>,
        // Mapping to indicate if a stage is active
        activeStage: Map<ID, bool>,
        // Mapping of Merkle roots for whitelist verification by stage ID
        stageWhitelist: Map<ID, Option<felt252>>,
        // Mapping of total NFTs minted in a stage by stage ID
        stageMintedCount: Map<ID, u128>,
        // Mapping of NFTs minted by a specific wallet in a stage
        userMintedCount: Map<ContractAddress, Map<ID, u128>>,
        // Mapping of total sales of stage by ID
        stageSales: Map<ID, Balance>,
        // Store sales commission
        commission: u32,
        // Mapping of payment tokens
        paymentTokens: Map<ContractAddress, bool>,
        // Store maximum allowed sales duration
        maxSalesDuration: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
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
    fn constructor(
        ref self: ContractState, owner: ContractAddress, paymentTokens: Span<ContractAddress>
    ) {
        self.ownable.initializer(owner);

        for token in paymentTokens {
            self.paymentTokens.write(*token, true);
        };

        self.commission.write(50); // per mille (default 5%)
        self.maxSalesDuration.write(7 * 24 * 60 * 60); // 7 days
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn updateStages(
            ref self: ContractState, stages: Span<Stage>, merkleRoots: Span<Option<felt252>>
        ) {
            assert(stages.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let owner = get_caller_address();
            let mut i = 0;
            while (i < stages.len()) {
                let stage = *stages.at(i);
                assert(!self.stageId.read(stage.id), Errors::STAGE_ID_USED);
                self.validateStage(stage, owner);
                let merkleRoot = *merkleRoots.at(i);

                self._set_stage(stage, merkleRoot, owner);
                self.emit(StageUpdated { owner, stage, merkleRoot });

                i += 1;
            }
        }

        fn removeStages(ref self: ContractState, stageIds: Span<ID>) {
            for stageId in stageIds {
                assert(self.activeStage.read(*stageId), Errors::STAGE_NOT_FOUND);
                assert(
                    self._is_stage_owner(*stageId, get_caller_address()), Errors::NOT_STAGE_OWNER
                );
                self.activeStage.write(*stageId, false);
                self.emit(StageRemoved { stageId: *stageId, });
            };
        }

        fn updateWhitelist(
            ref self: ContractState, stageIds: Span<u128>, merkleRoots: Span<Option<felt252>>
        ) {
            assert(stageIds.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);
            let mut i = 0;
            while (i < stageIds.len()) {
                let stageId = *stageIds.at(i);
                assert(self.activeStage.read(stageId), Errors::STAGE_NOT_FOUND);
                assert(
                    self._is_stage_owner(stageId, get_caller_address()), Errors::NOT_STAGE_OWNER
                );
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                self.emit(WhitelistUpdated { stageId, merkleRoot: *merkleRoots.at(i) });
                i += 1;
            }
        }

        fn removeWhitelist(ref self: ContractState, stageIds: Span<u128>) {
            for stageId in stageIds {
                assert(
                    self._is_stage_owner(*stageId, get_caller_address()), Errors::NOT_STAGE_OWNER
                );
                assert(self.activeStage.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(*stageId, Option::None);
                self.emit(WhitelistRemoved { stageId: *stageId, });
            };
        }

        fn buy(ref self: ContractState, stageId: ID, amount: u128, merkleProof: Span<felt252>) {
            let minter: ContractAddress = get_caller_address();
            let mintAmount: u128 = amount;
            let stage = self.getActiveStage(stageId);

            assert(amount > 0, Errors::ZERO_MINT_AMOUNT);

            let stageMintedAmount = self.stageMintedCount.read(stageId);
            let userMintedAmount = self.userMintedCount.entry(minter).read(stageId);

            assert(stageMintedAmount + mintAmount <= stage.maxAllocation, Errors::SOLD_OUT);
            assert(userMintedAmount + mintAmount <= stage.limit, Errors::EXCEED_LIMIT);

            if let Option::Some(root) = self.getWhitelist(stageId) {
                assert(self.verifyWhitelist(root, merkleProof, minter), Errors::WHITELIST_FAILED);
            }
            self.stageMintedCount.write(stageId, stageMintedAmount + mintAmount);
            self.userMintedCount.entry(minter).entry(stageId).write(userMintedAmount + mintAmount);

            let mintedTokens = nft_safe_batch_mint(stage.collection, minter, mintAmount.into());

            let price = mintAmount * stage.price;
            if price > 0 {
                payment_transfer_from(stage.payment, minter, get_contract_address(), price.into());
                let sales = self.stageSales.read(stageId);
                self.stageSales.write(stageId, sales + price);
            }

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
    }

    #[abi(embed_v0)]
    impl OpenLaunchpadManagerImpl of IOpenLaunchpadManager<ContractState> {
        fn withdrawSales(ref self: ContractState, stageId: ID) {
            self.reentrancy_guard.start();
            let owner = get_caller_address();
            assert(self._is_stage_owner(stageId, owner), Errors::NOT_STAGE_OWNER);

            let sales = self.stageSales.read(stageId);
            if sales > 0 {
                let fee = self._calculate_commission(sales);
                let payout = sales - fee;
                let stage = self.stages.read(stageId);

                payment_transfer(stage.payment, owner, payout.into());
                payment_transfer(stage.payment, self.ownable.owner(), fee.into());
                self.stageSales.write(stageId, 0);
                self.emit(SalesWithdrawn { owner, tokenPayment: stage.payment, amount: payout });
            }

            self.reentrancy_guard.end();
        }
    }

    #[abi(embed_v0)]
    impl LaunchpadProviderImpl of ILaunchpadProvider<ContractState> {
        fn validateStage(self: @ContractState, stage: Stage, owner: ContractAddress) {
            assert(stage.endTime > stage.startTime, Errors::INVALID_DURATION);

            assert(
                stage.endTime - stage.startTime <= self.maxSalesDuration.read(),
                Errors::SALE_DURATION_EXCEEDED
            );

            assert(self.paymentTokens.read(stage.payment), Errors::INVALID_PAYMENT_TOKEN);

            assert(
                access_has_role(stage.collection, DEFAULT_ADMIN_ROLE, owner)
                    || access_has_role(stage.collection, MINTER_ROLE, owner),
                Errors::UNAUTHORIZED_OWNER
            );

            assert(
                access_has_role(stage.collection, MINTER_ROLE, get_contract_address()),
                Errors::MISSING_MINTER_ROLE
            );
        }

        fn getStage(self: @ContractState, stageId: ID) -> Stage {
            return self.stages.read(stageId);
        }

        fn getActiveStage(self: @ContractState, stageId: ID) -> Stage {
            assert(self.activeStage.read(stageId), Errors::STAGE_NOT_FOUND);
            let stage = self.stages.read(stageId);

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

    #[abi(embed_v0)]
    impl OpenLaunchpadProviderImpl of IOpenLaunchpadProvider<ContractState> {
        fn verifyPaymentToken(self: @ContractState, paymentToken: ContractAddress) -> bool {
            return self.paymentTokens.read(paymentToken);
        }

        fn getSales(self: @ContractState, stageId: ID) -> Balance {
            return self.stageSales.read(stageId);
        }

        fn isClosed(self: @ContractState, stageId: ID) -> bool {
            return self.activeStage.read(stageId);
        }

        fn getMaxSalesDuration(self: @ContractState) -> u128 {
            return self.maxSalesDuration.read();
        }

        fn getCommission(self: @ContractState) -> u32 {
            return self.commission.read();
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

    #[generate_trait]
    pub impl InternalImpl of InternalImplTrait {
        fn _is_stage_owner(self: @ContractState, stageId: ID, owner: ContractAddress) -> bool {
            return self.stageOwner.read(stageId) == owner;
        }

        fn _set_stage(
            ref self: ContractState,
            stage: Stage,
            merkleRoot: Option<felt252>,
            owner: ContractAddress
        ) {
            self.stageId.write(stage.id, true);
            self.activeStage.write(stage.id, true);
            self.stageOwner.write(stage.id, owner);
            self.stages.write(stage.id, stage);
            self.stageWhitelist.write(stage.id, merkleRoot);
        }

        fn _calculate_commission(self: @ContractState, price: Balance) -> Balance {
            let commission: Balance = self.commission.read().into();

            if (commission > 0) {
                return commission * price / PERMYRIAD.into();
            }
            return 0;
        }
    }
}
