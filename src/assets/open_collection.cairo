// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
mod OpenCollection {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;
    use openmark::assets::interface::{IOpenCollection};
    use starknet::storage::Map;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct TokenMinted {
        #[key]
        pub to: ContractAddress,
        #[key]
        pub token_id: u256,
        #[key]
        pub uri: ByteArray,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // self storage
        token_index: u256,
        token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TokenMinted: TokenMinted,
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.erc721.initializer(name, symbol, "");
    }

    #[abi(embed_v0)]
    impl OpenCollectionImpl of IOpenCollection<ContractState> {
        fn mint_uris(ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>) {
            for uri in uris {
                let token_index = self._next_mint_index();
                self.token_uris.write(token_index, uri.clone());
                self.erc721.mint(to, token_index);
                self.emit(TokenMinted { to, token_id: token_index, uri: uri.clone() });
            };
        }

        fn mintURIs(ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>) {
            self.mint_uris(to, uris);
        }

        fn open_token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_uris.read(token_id)
        }

        fn openTokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.open_token_uri(tokenId)
        }

        fn getTokenIndex(self: @ContractState) -> u256 {
            return self.token_index.read();
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _next_mint_index(ref self: ContractState) -> u256 {
            let current_token_index = self.token_index.read();
            self.token_index.write(current_token_index + 1);
            current_token_index
        }
    }

    #[external(v0)]
    fn get_contract_name(self: @ContractState) -> felt252 {
        'Name Registry'
    }
}
