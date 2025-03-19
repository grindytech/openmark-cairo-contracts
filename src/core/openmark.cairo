// SPDX-License-Identifier: MIT
// OpenMark Contracts for Cairo

/// # OpenMark Contract
///
/// # This contract implements the OpenMark NFT marketplace on StarkNet, allowing users to:
/// - Buy: Purchase listed NFTs directly from sellers.
/// - Sell: List NFTs for sale with desired prices.

#[starknet::contract]
pub mod OpenMark {
    // use openzeppelin_access::ownable::interface::IOwnable;
    use core::array::ArrayTrait;
    use core::traits::Into;
    use core::array::SpanTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin::token::common::erc2981::interface::{
        IERC2981Dispatcher, IERC2981DispatcherTrait,
    };

    use starknet::{get_caller_address, get_tx_info, ContractAddress, get_block_timestamp};
    use starknet::ClassHash;

    use core::num::traits::Zero;

    use openmark::primitives::types::{Order, OrderType, Bag};
    use openmark::hasher::interface::IOffchainMessageHash;
    use openmark::hasher::{HasherComponent};
    use openmark::core::interface::{IOpenMark, IOpenMarkCamel, IOpenMarkProvider, IOpenMarkManager};
    use openmark::core::events::{OrderFilled, OrderCancelled};
    use openmark::core::errors::OMErrors as Errors;

    use openmark::primitives::constants::{PERMYRIAD};

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    /// Reentrancy
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );
    /// Upgradeable
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    /// Hasher
    component!(path: HasherComponent, storage: hasher, event: HasherEvent);

    #[abi(embed_v0)]
    /// Ownable
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    /// Reentrancy
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    /// Hasher
    impl HasherImpl = HasherComponent::HasherImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        HasherEvent: HasherComponent::Event,
        OrderFilled: OrderFilled,
        OrderCancelled: OrderCancelled,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        /// hash provider
        #[substorage(v0)]
        hasher: HasherComponent::Storage,
        /// OpenMark's commission (per mille)
        commission: u256,
        /// store used order signatures
        usedSignatures: starknet::storage::Map<felt252, bool>,
        /// store partial order
        partialSignatures: starknet::storage::Map<felt252, u128>,
        /// maximum royalty fee allowed
        maxRoyalty: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress ) {
        self.ownable.initializer(owner);
        self.commission.write(0); // 0%
        self.maxRoyalty.write(1000); // 10%
    }

    #[abi(embed_v0)]
    impl OpenMarkImpl of IOpenMark<ContractState> {
        fn buy(
            ref self: ContractState,
            seller: ContractAddress,
            order: Order,
            signature: Span<felt252>,
        ) {
            self.reentrancy_guard.start();
            let buyer = get_caller_address();
            self.verifyBuy(order, signature, seller, buyer);

            self.usedSignatures.write(self.hash_array(signature), true);
            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };
            nft_dispatcher.transfer_from(seller, buyer, order.tokenId.into());

            let price: u256 = order.price.into();
            self
                ._process_payment(
                    buyer, seller, price, order.payment, order.nftContract, order.tokenId,
                );

            self.emit(OrderFilled { seller, buyer, order });
            self.reentrancy_guard.end();
        }

        fn accept_offer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>,
        ) {
            self.reentrancy_guard.start();
            let seller = get_caller_address();
            self.verifyAcceptOffer(order, signature, seller, buyer);

            self.usedSignatures.write(self.hash_array(signature), true);

            let nft_dispatcher = IERC721Dispatcher { contract_address: order.nftContract };
            nft_dispatcher.transfer_from(seller, buyer, order.tokenId.into());

            let price: u256 = order.price.into();
            self
                ._process_payment(
                    buyer,
                    get_caller_address(),
                    price,
                    order.payment,
                    order.nftContract,
                    order.tokenId,
                );

            self.emit(OrderFilled { seller: get_caller_address(), buyer, order });
            self.reentrancy_guard.end();
        }

        fn buy_with_value(
            ref self: ContractState,
            seller: ContractAddress,
            order: Order,
            value: u128,
            signature: Span<felt252>,
        ) {
            self.reentrancy_guard.start();
            let buyer = get_caller_address();
            self.verifyBuy(order, signature, seller, buyer);

            let mut available = self.partialSignatures.read(self.hash_array(signature));
            if (available == 0) {
                available = order.value;
            }

            assert(value <= available, Errors::EXCEEDS_AVAILABLE_AMOUNT);

            if (value < available) {
                self.partialSignatures.write(self.hash_array(signature), available - value);
            } else if (value == available) {
                self.usedSignatures.write(self.hash_array(signature), true);
                self.partialSignatures.write(self.hash_array(signature), 0);
            }

            let nft_dispatcher = IERC1155Dispatcher { contract_address: order.nftContract };
            nft_dispatcher
                .safe_transfer_from(seller, buyer, order.tokenId.into(), value.into(), [].span());

            let price: u256 = (value * order.price).into();
            self
                ._process_payment(
                    buyer, seller, price, order.payment, order.nftContract, order.tokenId,
                );

            self.emit(OrderFilled { seller, buyer, order });
            self.reentrancy_guard.end();
        }

        fn accept_offer_with_value(
            ref self: ContractState,
            buyer: ContractAddress,
            order: Order,
            value: u128,
            signature: Span<felt252>,
        ) {
            self.reentrancy_guard.start();
            let seller = get_caller_address();
            self.verifyAcceptOffer(order, signature, seller, buyer);

            let mut available = self.partialSignatures.read(self.hash_array(signature));
            if (available == 0) {
                available = order.value;
            }
            assert(value <= available, Errors::EXCEEDS_AVAILABLE_AMOUNT);

            if (value < available) {
                self.partialSignatures.write(self.hash_array(signature), available - value);
            } else if (value == available) {
                self.usedSignatures.write(self.hash_array(signature), true);
                self.partialSignatures.write(self.hash_array(signature), 0);
            }

            let nft_dispatcher = IERC1155Dispatcher { contract_address: order.nftContract };
            nft_dispatcher
                .safe_transfer_from(seller, buyer, order.tokenId.into(), value.into(), [].span());

            let price: u256 = (value * order.price).into();
            self
                ._process_payment(
                    buyer,
                    get_caller_address(),
                    price,
                    order.payment,
                    order.nftContract,
                    order.tokenId,
                );

            self.emit(OrderFilled { seller: get_caller_address(), buyer, order });
            self.reentrancy_guard.end();
        }

        fn cancel_order(ref self: ContractState, order: Order, signature: Span<felt252>) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);

            assert(!self.usedSignatures.read(self.hash_array(signature)), Errors::SIGNATURE_USED);

            assert(
                self.hasher.verify_order(order, get_caller_address().into(), signature),
                Errors::INVALID_SIGNATURE,
            );
            self.usedSignatures.write(self.hash_array(signature), true);

            self.emit(OrderCancelled { who: get_caller_address(), order });
        }

        fn batch_buy(ref self: ContractState, bags: Span<Bag>) {
            for bag in bags {
                self.buy(*bag.seller, *bag.order, *bag.signature);
            }
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkCamelImpl of IOpenMarkCamel<ContractState> {
        fn acceptOffer(
            ref self: ContractState, buyer: ContractAddress, order: Order, signature: Span<felt252>,
        ) {
            self.accept_offer(buyer, order, signature);
        }

        fn cancelOrder(ref self: ContractState, order: Order, signature: Span<felt252>) {
            self.cancel_order(order, signature);
        }

        fn batchBuy(ref self: ContractState, bags: Span<Bag>) {
            self.batch_buy(bags);
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkProviderImpl of IOpenMarkProvider<ContractState> {
        fn getChainId(self: @ContractState) -> felt252 {
            get_tx_info().unbox().chain_id
        }

        fn getCommission(self: @ContractState) -> u256 {
            self.commission.read()
        }

        fn isUsedSignature(self: @ContractState, signature: Span<felt252>) -> bool {
            self.usedSignatures.read(self.hash_array(signature))
        }

        fn verifyBuy(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
            seller: ContractAddress,
            buyer: ContractAddress,
        ) {
            // 1. verify order
            self._verify_order(order, seller, buyer, OrderType::Buy);

            // 2. verify signature
            self._validate_order_signature(order, seller, signature);
        }

        fn verifyAcceptOffer(
            self: @ContractState,
            order: Order,
            signature: Span<felt252>,
            seller: ContractAddress,
            buyer: ContractAddress,
        ) {
            // 1. verify order
            self._verify_order(order, seller, buyer, OrderType::Offer);

            // 2. verify signature
            self._validate_order_signature(order, buyer, signature);
        }

        fn getVersion(self: @ContractState) -> (u32, u32, u32) {
            // version 0.2.2
            (0, 2, 2)
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkManagerImpl of IOpenMarkManager<ContractState> {
        fn set_commission(ref self: ContractState, new_commission: u256) {
            self.ownable.assert_only_owner();
            assert(new_commission < PERMYRIAD, Errors::INVALID_COMMISSION);
            self.commission.write(new_commission);
        }

        fn set_max_royalty(ref self: ContractState, new_royalty: u256) {
            self.ownable.assert_only_owner();
            self.maxRoyalty.write(new_royalty);
        }
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
        fn _validate_order_signature(
            self: @ContractState, order: Order, signer: ContractAddress, signature: Span<felt252>,
        ) {
            assert(signature.len() == 2, Errors::INVALID_SIGNATURE_LEN);
            assert(!self.usedSignatures.read(self.hash_array(signature)), Errors::SIGNATURE_USED);
            assert(
                self.hasher.verify_order(order, signer.into(), signature),
                Errors::INVALID_SIGNATURE,
            );
        }

        fn _verify_order(
            self: @ContractState,
            order: Order,
            seller: ContractAddress,
            buyer: ContractAddress,
            order_type: OrderType,
        ) {
            assert(order.expiry > get_block_timestamp().into(), Errors::ORDER_EXPIRED);
            assert(order.option == order_type, Errors::INVALID_ORDER_TYPE);

            assert(!seller.is_zero(), Errors::ZERO_ADDRESS);
            assert(!buyer.is_zero(), Errors::ZERO_ADDRESS);
        }

        fn _calculate_commission(self: @ContractState, price: u256) -> u256 {
            price * self.commission.read().into() / PERMYRIAD
        }

        /// Processes a payment from sender to a receiver.
        ///
        /// # Parameters:
        /// - `sender`: The sender address.
        /// - `receiver`: The address to receive the payment.
        /// - `amount`: The amount to be transferred.
        /// - `payment_token`: The address of the payment token contract.
        /// - `nft_contract`: The address of the nft contract.
        /// - `token_id`: token id traded.
        fn _process_payment(
            self: @ContractState,
            sender: ContractAddress,
            receiver: ContractAddress,
            amount: u256,
            payment_token: ContractAddress,
            nft_contract: ContractAddress,
            token_id: u128,
        ) {
            // Check if the contract supports IERC2981 (royalty standard)
            let royalty_dispatcher = IERC2981Dispatcher { contract_address: nft_contract };
            let (royalty_receiver, mut royalty_amount) = royalty_dispatcher
                .royalty_info(token_id.into(), amount);

            // Ensure the royaltyAmount does not exceed the maximum allowed royalty
            let max_royalty_amount = (amount * self.maxRoyalty.read()) / PERMYRIAD;
            if (royalty_amount > max_royalty_amount) {
                royalty_amount = max_royalty_amount;
            }

            // Calculate the fee and payout
            let commission = self._calculate_commission(amount);
            let payout = amount - royalty_amount - commission;

            let token_dispatcher = IERC20Dispatcher { contract_address: payment_token };
            token_dispatcher.transfer_from(sender, receiver, payout);

            if royalty_amount > 0 {
                token_dispatcher.transfer_from(sender, royalty_receiver, royalty_amount);
            }

            if commission > 0 {
                token_dispatcher.transfer_from(sender, self.owner(), commission);
            }
        }
    }
}
