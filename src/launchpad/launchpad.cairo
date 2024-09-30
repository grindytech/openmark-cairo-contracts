#[starknet::contract]
pub mod Launchpad {
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
        ILaunchpad, ILaunchpadProvider, ILaunchpadManager, ILaunchpadHelper
    };
    use openmark::launchpad::events::{
        StageUpdated, StageRemoved, WhitelistUpdated, WhitelistRemoved, SalesWithdrawn,
        TokensBought, LaunchpadClosed
    };
    use openmark::primitives::types::{Stage, ID, Balance};
    use openmark::primitives::constants::{MINTER_ROLE, PERMYRIAD};
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::primitives::utils::{
        nft_safe_batch_mint, payment_transfer_from, payment_transfer, payment_balance_of,
        access_has_role, verify_payment_token, get_commission
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
        // Mapping of all stages by ID
        stages: Map<ID, Stage>,
        // Mapping to indicate if a stage is active
        activeStage: Map<ID, bool>,
        // Mapping of Merkle roots for whitelist verification by stage ID
        stageWhitelist: Map<ID, Option<felt252>>,
        // Mapping of total NFTs minted in a stage by stage ID
        stageMintedCount: Map<ID, u128>,
        // Mapping of NFTs minted by a specific wallet in a stage
        userMintedCount: Map<ContractAddress, Map<ID, u128>>,
        // Total deposit for create launchpad
        depositAmount: Balance,
        // Token address of depositAmount
        depositPaymentToken: ContractAddress,
        // Flag indicating if the launchpad is closed
        isClosed: bool,
        // URI for the launchpad metadata
        uri: ByteArray,
        // Address of the factory contract
        factory: ContractAddress,
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
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        uri: ByteArray,
        depositAmount: Balance,
        depositPaymentToken: ContractAddress,
        factory: ContractAddress,
    ) {
        self.isClosed.write(false);

        self.ownable.initializer(owner);
        self.uri.write(uri);
        self.depositAmount.write(depositAmount);
        self.depositPaymentToken.write(depositPaymentToken);
        self.factory.write(factory);
    }

    #[abi(embed_v0)]
    impl LaunchpadImpl of ILaunchpad<ContractState> {
        fn updateStages(
            ref self: ContractState, stages: Span<Stage>, merkleRoots: Span<Option<felt252>>
        ) {
            self.ownable.assert_only_owner();
            assert(stages.len() == merkleRoots.len(), Errors::LENGTH_MISMATCH);

            let owner = get_caller_address();
            let mut i = 0;
            while (i < stages.len()) {
                let stage = *stages.at(i);
                self.validateStage(stage, owner);
                let merkleRoot = *merkleRoots.at(i);

                self._set_stage(stage, merkleRoot);
                self.emit(StageUpdated { owner, stage, merkleRoot });

                i += 1;
            }
        }

        fn removeStages(ref self: ContractState, stageIds: Span<ID>) {
            self.ownable.assert_only_owner();
            for stageId in stageIds {
                assert(self.activeStage.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.activeStage.write(*stageId, false);
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
                assert(self.activeStage.read(stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(stageId, *merkleRoots.at(i));
                self.emit(WhitelistUpdated { stageId, merkleRoot: *merkleRoots.at(i) });
                i += 1;
            }
        }

        fn removeWhitelist(ref self: ContractState, stageIds: Span<u128>) {
            self.ownable.assert_only_owner();
            for stageId in stageIds {
                assert(self.activeStage.read(*stageId), Errors::STAGE_NOT_FOUND);
                self.stageWhitelist.write(*stageId, Option::None);
                self.emit(WhitelistRemoved { stageId: *stageId });
            };
        }

        fn buy(ref self: ContractState, stageId: ID, amount: u128, merkleProof: Span<felt252>) {
            assert(!self.isClosed.read(), Errors::LAUNCHPAD_CLOSED);
            assert(amount > 0, Errors::ZERO_MINT_AMOUNT);

            let minter: ContractAddress = get_caller_address();
            let stage = self.getActiveStage(stageId);

            let stageMintedAmount = self.stageMintedCount.read(stageId);
            let userMintedAmount = self.userMintedCount.entry(minter).read(stageId);

            assert(stageMintedAmount + amount <= stage.maxAllocation, Errors::SOLD_OUT);
            assert(userMintedAmount + amount <= stage.limit, Errors::EXCEED_LIMIT);

            if let Option::Some(root) = self.getWhitelist(stageId) {
                assert(self.verifyWhitelist(root, merkleProof, minter), Errors::WHITELIST_FAILED);
            }

            let mintedTokens = nft_safe_batch_mint(stage.collection, minter, amount.into());

            let price = amount * stage.price;
            payment_transfer_from(stage.payment, minter, get_contract_address(), price.into());

            self.stageMintedCount.write(stageId, stageMintedAmount + amount);
            self.userMintedCount.entry(minter).entry(stageId).write(userMintedAmount + amount);

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
    impl LaunchpadProviderImpl of ILaunchpadProvider<ContractState> {
        fn validateStage(self: @ContractState, stage: Stage, owner: ContractAddress) {
            assert(
                verify_payment_token(self.factory.read(), stage.payment),
                Errors::INVALID_PAYMENT_TOKEN
            );

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
    impl LaunchpadHelperImpl of ILaunchpadHelper<ContractState> {
        fn setLaunchpadUri(ref self: ContractState, uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.uri.write(uri);
        }

        fn getLaunchpadUri(self: @ContractState) -> ByteArray {
            self.uri.read()
        }

        fn getFactory(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }

        fn isClosed(self: @ContractState) -> bool {
            self.isClosed.read()
        }

        fn launchpadDeposit(self: @ContractState) -> (ContractAddress, Balance) {
            (self.depositPaymentToken.read(), self.depositAmount.read())
        }
    }

    #[abi(embed_v0)]
    impl LaunchpadManagerImpl of ILaunchpadManager<ContractState> {
        fn withdrawSales(ref self: ContractState, tokens: Span<ContractAddress>) {
            self.ownable.assert_only_owner();

            let owner = get_caller_address();
            for token in tokens {
                let sales = self._withdraw(owner, *token, false);

                if let Option::Some(amount) = sales.try_into() {
                    self.emit(SalesWithdrawn { owner, tokenPayment: *token, amount });
                }
            };
        }

        fn closeLaunchpad(ref self: ContractState, tokens: Span<ContractAddress>) {
            self.ownable.assert_only_owner();

            let owner = get_caller_address();
            for token in tokens {
                let sales = self._withdraw(owner, *token, true);
                if let Option::Some(amount) = sales.try_into() {
                self.emit(SalesWithdrawn { owner, tokenPayment: *token, amount});
                }
            };

            self.isClosed.write(true);
            self.emit(LaunchpadClosed { launchpad: get_contract_address(), owner });
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
        fn _set_stage(ref self: ContractState, stage: Stage, merkleRoot: Option<felt252>) {
            self.activeStage.write(stage.id, true);
            self.stages.write(stage.id, stage);
            self.stageWhitelist.write(stage.id, merkleRoot);
        }

        fn _calculate_commission(self: @ContractState, price: u256) -> u256 {
            let commission = get_commission(self.factory.read()).into();

            if (commission > 0) {
                return commission * price / PERMYRIAD.into();
            }
            return 0;
        }

        fn _withdraw(
            self: @ContractState, owner: ContractAddress, token: ContractAddress, all: bool
        ) -> u256 {
            let mut sales: u256 = 0;

            if (all && token == self.depositPaymentToken.read()) {
                payment_transfer(token, get_caller_address(), self.depositAmount.read().into());
                sales = payment_balance_of(token, get_contract_address());
            } else {
                sales = payment_balance_of(token, get_contract_address())
                    - self.depositAmount.read().into();
            }

            let fee = self._calculate_commission(sales);
            let payout = sales - fee.into();

            payment_transfer(token, owner, payout.into());
            payment_transfer(token, self.factory.read(), fee.into());
            sales
        }
    }
}
