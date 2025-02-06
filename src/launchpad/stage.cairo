#[starknet::component]
pub mod StageComponent {
    use openzeppelin::merkle_tree::merkle_proof::{verify};
    use openzeppelin::merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::pedersen::{PedersenTrait, pedersen};

    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map, Vec, VecTrait,
        MutableVecTrait,
    };

    use starknet::{
        ContractAddress, get_block_timestamp, get_contract_address,
    };
    use openmark::launchpad::errors::LPErrors as Errors;

    use openmark::launchpad::interface::{IOStage};
    use openmark::launchpad::events::{SalesWithdrawn, LaunchpadClosed};
    use openmark::primitives::types::{Stage};
    use openmark::primitives::constants::{PERMYRIAD};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    #[storage]
    struct Storage {
        // Stored stage info
        stage: Stage,
        // Stored merkle root whitelist
        rootWhitelist: Option::<felt252>,
        // Store collections being used for whitelist
        collectionWhitelists: Vec<ContractAddress>,
        // Mapping of total NFTs minted in a stage by stage ID
        stageMintedCount: u256,
        // Mapping of NFTs minted by a specific wallet in a stage
        userMintedCount: Map<ContractAddress, u256>,
        // Flag indicating if the launchpad is closed
        isClosed: bool,
        // Stored commission
        commission: u128,
        // Address receive commission
        commissionReceiver: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SalesWithdrawn: SalesWithdrawn,
        LaunchpadClosed: LaunchpadClosed,
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            stage: Stage,
            rootWhitelist: Option::<felt252>,
            collectionWhitelists: Span<ContractAddress>,
            commission: u128,
            commissionReceiver: ContractAddress,
        ) {
            self.isClosed.write(false);
            self.stage.write(stage);
            self.rootWhitelist.write(rootWhitelist);

            for collection in collectionWhitelists {
                self.collectionWhitelists.append().write(*collection);
            };

            self.commission.write(commission);
            self.commissionReceiver.write(commissionReceiver);
        }

        fn withdrawSales(ref self: ComponentState<TContractState>, receiver: ContractAddress) {
            let paymentToken = self.stage.payment.read();
            let mut sales: u256 = 0;

            let token_dispatcher = IERC20Dispatcher { contract_address: paymentToken };

            sales = token_dispatcher.balance_of(get_contract_address());

            let commission = self.commission.read().into() * sales / PERMYRIAD.into();
            let payout = sales - commission.into();

            token_dispatcher.transfer(receiver, payout.into());
            token_dispatcher.transfer(self.commissionReceiver.read(), commission.into());

            if let Option::Some(amount) = sales.try_into() {
                self.emit(SalesWithdrawn { owner: receiver, tokenPayment: paymentToken, amount });
            }
        }

        fn closeStage(ref self: ComponentState<TContractState>) {
            self.isClosed.write(true);
        }
    }

    #[embeddable_as(OStageImpl)]
    impl OStage<
        TContractState, +HasComponent<TContractState>,
    > of IOStage<ComponentState<TContractState>> {
        fn getStage(self: @ComponentState<TContractState>) -> Stage {
            return self.stage.read();
        }

        fn getMintedCount(self: @ComponentState<TContractState>) -> u256 {
            return self.stageMintedCount.read();
        }

        fn getUserMintedCount(
            self: @ComponentState<TContractState>, minter: ContractAddress,
        ) -> u256 {
            return self.userMintedCount.entry(minter).read();
        }

        fn validateStage(self: @ComponentState<TContractState>) -> bool {
            assert(!self.isClosed.read(), Errors::STAGE_CLOSED);

            let currentTimestamp: u128 = get_block_timestamp().into();
            assert(currentTimestamp >= self.stage.startTime.read(), Errors::STAGE_NOT_STARTED);
            assert(currentTimestamp <= self.stage.endTime.read(), Errors::STAGE_ENDED);

            return true;
        }


        fn validateWhitelist(
            self: @ComponentState<TContractState>,
            minter: ContractAddress,
            merkleProof: Span<felt252>,
        ) -> bool {
            // Validate merkle tree
            if let Option::Some(root) = self.rootWhitelist.read() {
                assert(verify_merkle_proof(root, merkleProof, minter), Errors::ROOT_WHITELIST_FAILED);
            }

            // Validate collection ownership
            for i in 0..self.collectionWhitelists.len() {
                let collection = self.collectionWhitelists.at(i).read();
                let nft_dispatcher = IERC721Dispatcher { contract_address: collection };
                assert(nft_dispatcher.balance_of(minter) > 0, Errors::COLLECTION_WHITELIST_FAILED);
            };

            return true;
        }
    }

    fn verify_merkle_proof(
        merkleRoot: felt252, merkleProof: Span<felt252>, minter: ContractAddress,
    ) -> bool {
        let hash_state = PedersenTrait::new(0);
        let leaf_hash = pedersen(0, hash_state.update_with(minter).update_with(1).finalize());
        return verify::<PedersenCHasher>(merkleProof, merkleRoot, leaf_hash);
    }
}
