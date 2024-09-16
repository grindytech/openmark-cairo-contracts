// SPDX-License-Identifier: MIT

#[starknet::component]
pub mod OMERC721Component {
    use openzeppelin_token::erc721::ERC721Component::ERC721Impl;
    use openzeppelin_token::erc721::ERC721Component::InternalImpl as ERC721InternalImpl;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::Map;
    use openmark::token::interface::{IOMERC721};
    use openmark::token::events::{TokenMinted, TokenURIUpdated};
    use openzeppelin::token::erc721::interface::{IERC721Metadata};

    #[storage]
    struct Storage {
        token_index: u256,
        token_uris: Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        TokenMinted: TokenMinted,
        TokenURIUpdated: TokenURIUpdated,
    }

    #[embeddable_as(OMERC721Impl)]
    impl OMERC721<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IOMERC721<ComponentState<TContractState>> {
        fn current_mint_index(self: @ComponentState<TContractState>) -> u256 {
            return self.token_index.read();
        }

        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            let erc721_component = get_dep_component!(self, ERC721);
            erc721_component.ERC721_name.read()
        }
        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            let erc721_component = get_dep_component!(self, ERC721);
            erc721_component.ERC721_symbol.read()
        }

        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            let erc721_component = get_dep_component!(self, ERC721);

            erc721_component._require_owned(token_id);

            let token_uri = self.token_uris.read(token_id);
            let base_uri = erc721_component._base_uri();

            if base_uri.len() == 0 {
                return token_uri;
            }
            if token_uri.len() > 0 {
                return base_uri + token_uri;
            }
            IERC721Metadata::token_uri(erc721_component, token_id)
        }
    }

    //
    // Internal
    //
    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn _safe_batch_mint(
            ref self: ComponentState<TContractState>, to: ContractAddress, quantity: u256
        ) -> Span<u256> {
            let mut minted_tokens = ArrayTrait::new();
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);

            let mut i = 0;
            while i < quantity {
                let token_index = self._next_mint_index();
                erc721_component.mint(to, token_index);
                minted_tokens.append(token_index);
                self.emit(TokenMinted { to, token_id: token_index, uri: "" });

                i += 1;
            };
            return minted_tokens.span();
        }

        fn _safe_batch_mint_with_uris(
            ref self: ComponentState<TContractState>, to: ContractAddress, uris: Span<ByteArray>
        ) -> Span<u256> {
            let mut minted_tokens = ArrayTrait::new();
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);

            for uri in uris {
                let token_index = self._next_mint_index();
                erc721_component.mint(to, token_index);
                self.token_uris.write(token_index, uri.clone());
                minted_tokens.append(token_index);
                self.emit(TokenMinted { to, token_id: token_index, uri: uri.clone() });
            };
            return minted_tokens.span();
        }

        fn _set_token_uri(
            ref self: ComponentState<TContractState>, token_id: u256, uri: ByteArray
        ) {
            self.token_uris.write(token_id, uri.clone());
            self.emit(TokenURIUpdated { token_id, uri, });
        }

        fn _set_base_uri(ref self: ComponentState<TContractState>, base_uri: ByteArray) {
            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            erc721_component._set_base_uri(base_uri);
        }

        /// Returns the current token_index and increments it for the next use.
        /// This ensures each token has a unique ID.
        fn _next_mint_index(ref self: ComponentState<TContractState>) -> u256 {
            let current_token_index = self.token_index.read();
            self.token_index.write(current_token_index + 1);
            current_token_index
        }
    }
}
