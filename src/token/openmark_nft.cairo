#[starknet::contract]
pub mod OpenMarkNFT {
    use openzeppelin::token::erc721::interface::IERC721Metadata;
    use openzeppelin::token::erc721::interface::IERC721MetadataDispatcher;
    use core::byte_array::ByteArrayTrait;
    use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{
        ERC721Component, ERC721Component::Errors as ERC721Errors, ERC721HooksEmptyImpl
    };
    use openzeppelin::access::ownable::OwnableComponent;

    use openmark::token::events::{TokenMinted, TokenURIUpdated};

    use starknet::ContractAddress;
    use openmark::token::interface::IOpenMarkNFT;
    use starknet::{get_caller_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        token_index: u256,
        token_uris: LegacyMap<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TokenMinted: TokenMinted,
        TokenURIUpdated: TokenURIUpdated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray
    ) {
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);
        self.token_index.write(0);
    }

    #[abi(embed_v0)]
    impl OpenMarkNFTImpl of IOpenMarkNFT<ContractState> {
        fn safe_mint(ref self: ContractState, to: ContractAddress) {
            let token_index = next_token_index(ref self);
            self.erc721.mint(to, token_index);

            self
                .emit(
                    TokenMinted { caller: get_caller_address(), to, token_id: token_index, uri: "" }
                );
        }

        fn safe_mint_with_uri(ref self: ContractState, to: ContractAddress, uri: ByteArray) {
            let token_index = next_token_index(ref self);
            self.erc721.mint(to, token_index);
            self.token_uris.write(token_index, uri.clone());
            self.emit(TokenMinted { caller: get_caller_address(), to, token_id: token_index, uri });
        }


        fn safe_batch_mint(ref self: ContractState, to: ContractAddress, quantity: u256) {
            let mut token_indexs = ArrayTrait::new();
            let mut i = 0;
            while i < quantity {
                let token_index = next_token_index(ref self);
                self.erc721.mint(to, token_index);
                token_indexs.append(token_index);
                self
                    .emit(
                        TokenMinted {
                            caller: get_caller_address(), to, token_id: token_index, uri: ""
                        }
                    );

                i += 1;
            };
        }


        fn safe_batch_mint_with_uris(
            ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>
        ) {
            let mut i = 0;
            while i < uris
                .len() {
                    let token_index = next_token_index(ref self);
                    self.erc721.mint(to, token_index);
                    self.token_uris.write(token_index, uris.at(i).clone());
                    self
                        .emit(
                            TokenMinted {
                                caller: get_caller_address(),
                                to,
                                token_id: token_index,
                                uri: uris.at(i).clone()
                            }
                        );

                    i += 1;
                };
        }

        fn set_token_uri(ref self: ContractState, token_id: u256, uri: ByteArray) {
            assert(
                self.erc721.owner_of(token_id) == get_caller_address(), ERC721Errors::UNAUTHORIZED
            );
            self.token_uris.write(token_id, uri.clone());
            self.emit(TokenURIUpdated { who: get_caller_address(), token_id, uri, });
        }

        fn get_token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            let uri = self.token_uris.read(token_id);
            if (uri.len() != 0) {
                uri
            } else {
                IERC721Metadata::token_uri(self.erc721, token_id)
            }
        }

        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.erc721._set_base_uri(base_uri);
        }
    }

    /// Returns the current token_index and increments it for the next use.
    /// This ensures each token has a unique ID.
    fn next_token_index(ref self: ContractState) -> u256 {
        let current_token_index = self.token_index.read();
        self.token_index.write(current_token_index + 1);
        current_token_index
    }
}
