// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts for Cairo
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

#[starknet::contract]
pub mod OpenCollection {
    use SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::token::erc721::interface::IERC721_ID;
    use openzeppelin::token::common::erc2981::interface::{IERC2981, IERC2981_ID};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;
    use openmark::assets::interface::{IOpenCollection};
    use starknet::storage::Map;
    use openzeppelin::token::erc721::interface::{IERC721Metadata, IERC721MetadataCamelOnly};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct TokenMinted {
        #[key]
        pub to: ContractAddress,
        #[key]
        pub token_id: u256,
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
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TokenMinted: TokenMinted,
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.erc721.initializer(name, symbol, "");
        self.src5.register_interface(IERC2981_ID);
        self.src5.register_interface(IERC721_ID);
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

        fn getTokenIndex(self: @ContractState) -> u256 {
            return self.token_index.read();
        }
    }

    // Implement IERC721Metadata to override tokenURI and avoid duplicate token_uri
    #[abi(embed_v0)]
    impl ERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc721.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.symbol()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.token_uris.read(token_id)
        }
    }

    #[abi(embed_v0)]
    impl IERC721MetadataCamelOnlyImpl of IERC721MetadataCamelOnly<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.token_uris.read(tokenId)
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
}
