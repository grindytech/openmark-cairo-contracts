#[starknet::component]
pub mod StageComponent {
    use openzeppelin_merkle_tree::merkle_proof::{verify};
    use openzeppelin_merkle_tree::hashes::{PedersenCHasher, PoseidonCHasher};
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::pedersen::{PedersenTrait, pedersen};

    use starknet::{
        ContractAddress, get_contract_address
    };
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use openmark::launchpad::interface::{ IOStage};
    use openmark::launchpad::events::{
         SalesWithdrawn, LaunchpadClosed
    };
    use openmark::primitives::types::{Stage};
    use openmark::primitives::constants::{PERMYRIAD};
    use openmark::primitives::utils::{
        payment_transfer, payment_balance_of
    };

    #[storage]
    struct Storage {
        // Stored stage info
        stage: Stage,
        // Mapping of Merkle roots for whitelist verification by stage ID
        stageWhitelist: Option<felt252>,
        // Mapping of total NFTs minted in a stage by stage ID
        stageMintedCount: u128,
        // Mapping of NFTs minted by a specific wallet in a stage
        userMintedCount: Map<ContractAddress, u128>,
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
            commission: u128,
            commissionReceiver: ContractAddress,
        ) {
            self.isClosed.write(false);
            self.commission.write(commission);
            self.commissionReceiver.write(commissionReceiver);
        }

        fn withdrawSales(ref self: ComponentState<TContractState>, receiver: ContractAddress) {
            let paymentToken = self.stage.payment.read();
            let mut sales: u256 = 0;
            sales = payment_balance_of(paymentToken, get_contract_address());

            let fee = self.commission.read().into() * sales / PERMYRIAD.into();
            let payout = sales - fee.into();

            payment_transfer(paymentToken, receiver, payout.into());
            payment_transfer(paymentToken, self.commissionReceiver.read(), fee.into());

            if let Option::Some(amount) = sales.try_into() {
                self.emit(SalesWithdrawn { owner: receiver, tokenPayment: paymentToken, amount });
            }
        }

        fn closeStage(ref self:ComponentState<TContractState>) {
            self.isClosed.write(false);
        }
    }

    #[embeddable_as(OStageImpl)]
    impl OStage<
        TContractState, +HasComponent<TContractState>
    > of IOStage<ComponentState<TContractState>> {
        fn getStage(self: @ComponentState<TContractState>) -> Stage {
            return self.stage.read();
        }

        fn getMintedCount(self: @ComponentState<TContractState>) -> u128 {
            return self.stageMintedCount.read();
        }

        fn getUserMintedCount(
            self: @ComponentState<TContractState>, minter: ContractAddress
        ) -> u128 {
            return self.userMintedCount.entry(minter).read();
        }

        fn verifyWhitelist(
            self: @ComponentState<TContractState>,
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
}
