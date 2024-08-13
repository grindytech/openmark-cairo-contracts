#[starknet::contract]
pub mod GameItem {
    use openzeppelin::token::erc721::interface::ERC721ABI;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::token::erc721::interface::{IERC721, IERC721Dispatcher};
    use openzeppelin::token::erc721::interface::{IERC721Metadata, IERC721MetadataDispatcher};
    use core::byte_array::ByteArrayTrait;
    use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait as ERC721Internal;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{
        ERC721Component, ERC721Component::Errors as ERC721Errors, ERC721HooksEmptyImpl
    };

    use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

    use openmark::token::events::{TokenMinted, TokenURIUpdated};
    use openmark::primitives::constants::{MINTER_ROLE};

    use starknet::ContractAddress;
    use openmark::token::interface::{
        IOpenMarkNFT, IOpenMarNFTkMetadata, IOpenMarkNFTMetadataCamel, IOpenMarkNFTCamel
    };
    use starknet::{get_caller_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721ImplImpl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        token_index: u256,
        token_uris: starknet::storage::Map<u256, ByteArray>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
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
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);

        self.erc721.initializer(name, symbol, base_uri);
        self.token_index.write(0);
    }

    #[abi(embed_v0)]
    impl OpenMarkNFTImpl of IOpenMarkNFT<ContractState> {
        fn safe_batch_mint(ref self: ContractState, to: ContractAddress, quantity: u256) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            let mut token_indexs = ArrayTrait::new();
            let mut i = 0;
            while i < quantity {
                let token_index = next_token_index(ref self);
                self.erc721.mint(to, token_index);
                token_indexs.append(token_index);
                self.emit(TokenMinted { to, token_id: token_index, uri: "" });

                i += 1;
            };
        }


        fn safe_batch_mint_with_uris(
            ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            for uri in uris {
                let token_index = next_token_index(ref self);
                self.erc721.mint(to, token_index);
                self.token_uris.write(token_index, uri.clone());
                self.emit(TokenMinted { to, token_id: token_index, uri: uri.clone() });
            };
        }

        fn set_token_uri(ref self: ContractState, token_id: u256, uri: ByteArray) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.token_uris.write(token_id, uri.clone());
            self.emit(TokenURIUpdated { token_id, uri });
        }

        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.erc721._set_base_uri(base_uri);
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkNFTCamelImpl of IOpenMarkNFTCamel<ContractState> {
        fn safeBatchMint(ref self: ContractState, to: ContractAddress, quantity: u256) {
            self.safe_batch_mint(to, quantity);
        }

        fn safeBatchMintWithURIs(
            ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>
        ) {
            self.safe_batch_mint_with_uris(to, uris);
        }

        fn setTokenURI(ref self: ContractState, tokenId: u256, tokenURI: ByteArray) {
            self.set_token_uri(tokenId, tokenURI);
        }

        fn setBaseURI(ref self: ContractState, baseURI: ByteArray) {
            self.set_base_uri(baseURI);
        }
    }

    #[abi(embed_v0)]
    impl IOpenMarNFTkMetadataImpl of IOpenMarNFTkMetadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_name.read()
        }
        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.ERC721_symbol.read()
        }
        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721._require_owned(token_id);

            let token_uri = self.token_uris.read(token_id);
            let base_uri = self.erc721._base_uri();

            if base_uri.len() == 0 {
                return token_uri;
            }
            if token_uri.len() > 0 {
                return base_uri + token_uri;
            }
            IERC721Metadata::token_uri(self.erc721, token_id)
        }
    }

    #[abi(embed_v0)]
    impl IOpenMarNFTkMetadataCamelOnlyImpl of IOpenMarkNFTMetadataCamel<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.token_uri(tokenId)
        }
    }

    #[abi(embed_v0)]
    impl IOpenMarkSRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            self.erc721.supports_interface(interface_id)
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
