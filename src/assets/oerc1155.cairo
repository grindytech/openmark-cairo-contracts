// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
mod OERC1155 {
    use openzeppelin::token::erc1155::interface::IERC1155_ID;
    use SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::ContractAddress;
    use openzeppelin::token::common::erc2981::interface::{IERC2981, IERC2981_ID};
    use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait as AccessInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openmark::primitives::constants::{MINTER_ROLE, PERMYRIAD};
    use openmark::assets::errors::Errors;

    use openmark::assets::interface::{IERC1155Minter, IOERC1155Handler};

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);

    // Access Control
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlCamelImpl = AccessControlComponent::AccessControlCamelImpl<ContractState>;

    // ERC1155 Mixin
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // self storage
        name: ByteArray,
        symbol: ByteArray,
        maxTokenId: u256,
        royaltyPercentage: u256,
        royaltyReceiver: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        uri: ByteArray,
        maxTokenId: u256,
        royaltyPercentage: u256,
    ) {
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);
        self.erc1155.initializer(uri);
        self.maxTokenId.write(maxTokenId);
        self.name.write(name);
        self.symbol.write(symbol);
        self.royaltyPercentage.write(royaltyPercentage);
        self.royaltyReceiver.write(owner);
        self.src5.register_interface(IERC2981_ID);
        self.src5.register_interface(IERC1155_ID);
    }

    #[abi(embed_v0)]
    impl ERC1155MinterImpl of IERC1155Minter<ContractState> {
        fn mint(
            ref self: ContractState,
            to: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>,
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            assert(tokenId < self.maxTokenId.read(), Errors::INVALID_TOKEN_ID);

            self.erc1155.mint_with_acceptance_check(to, tokenId, value, data);
        }

        fn mint_batch(
            ref self: ContractState,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            for tokenId in tokenIds {
                assert(*tokenId < self.maxTokenId.read(), Errors::INVALID_TOKEN_ID);
            };
            self.erc1155.batch_mint_with_acceptance_check(to, tokenIds, values, data);
        }

        fn mintBatch(
            ref self: ContractState,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            self.mint_batch(to, tokenIds, values, data);
        }
    }

    #[abi(embed_v0)]
    impl OERC1155HandlerImpl of IOERC1155Handler<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn setURI(ref self: ContractState, newBaseURI: ByteArray, newMaxTokenId: u256) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            self.erc1155._set_base_uri(newBaseURI);
            self.maxTokenId.write(newMaxTokenId);
        }

        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.erc1155.uri(tokenId)
        }

        fn getMaxTokenId(self: @ContractState) -> u256 {
            self.maxTokenId.read()
        }

        fn setRoyalty(
            ref self: ContractState, royaltyPercentage: u256, royaltyReceiver: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.royaltyPercentage.write(royaltyPercentage);
            self.royaltyReceiver.write(royaltyReceiver);
        }

        fn getRoyalty(self: @ContractState) -> (u256, ContractAddress) {
            return (self.royaltyPercentage.read(), self.royaltyReceiver.read());
        }
    }

    //**** Implement IERC2981 Royalties ****//
    #[abi(embed_v0)]
    impl IERC2981Impl of IERC2981<ContractState> {
        fn royalty_info(
            self: @ContractState, token_id: u256, sale_price: u256,
        ) -> (ContractAddress, u256) {
            let royaltyAmount = (sale_price * self.royaltyPercentage.read()) / PERMYRIAD;
            return (self.royaltyReceiver.read(), royaltyAmount);
        }
    }
}
