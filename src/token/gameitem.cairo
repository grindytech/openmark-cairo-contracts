#[starknet::contract]
pub mod GameItem {
    use openzeppelin::token::erc721::interface::ERC721ABI;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait as ERC721Internal;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};

    use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

    use openmark::token::om_erc721::OMERC721Component;
    use openmark::token::errors::NFTErrors as Errors;
    use openmark::primitives::constants::{MINTER_ROLE};

    use starknet::ContractAddress;
    use openmark::token::interface::{IOpenMarkNFT, IOpenMarkNFTMetadataCamel, IOpenMarkNFTCamel};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: OMERC721Component, storage: om_erc721, event: OMERC721Event);

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;

    #[abi(embed_v0)]
    impl OMERC721Impl = OMERC721Component::OMERC721Impl<ContractState>;
    impl OMERC721InternalImpl = OMERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlCamelImpl = AccessControlComponent::AccessControlCamelImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        om_erc721: OMERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        totalSupply: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        OMERC721Event: OMERC721Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        baseURI: ByteArray,
        totalSupply: u256,
    ) {
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);

        self.erc721.initializer(name, symbol, baseURI);
        self.totalSupply.write(totalSupply);
    }

    #[abi(embed_v0)]
    impl OpenNFTImpl of IOpenMarkNFT<ContractState> {
        fn safe_batch_mint(
            ref self: ContractState, to: ContractAddress, quantity: u256
        ) -> Span<u256> {
            assert(
                self.om_erc721.current_mint_index() + quantity <= self.totalSupply.read(),
                Errors::EXCEED_TOTAL_SUPPLY
            );
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            return self.om_erc721._safe_batch_mint(to, quantity);
        }

        fn safe_batch_mint_with_uris(
            ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>
        ) -> Span<u256> {
            assert(
                self.om_erc721.current_mint_index() + uris.len().into() <= self.totalSupply.read(),
                Errors::EXCEED_TOTAL_SUPPLY
            );

            self.accesscontrol.assert_only_role(MINTER_ROLE);
            return self.om_erc721._safe_batch_mint_with_uris(to, uris);
        }
    }

    #[abi(embed_v0)]
    impl OpenMarkNFTCamelImpl of IOpenMarkNFTCamel<ContractState> {
        fn safeBatchMint(
            ref self: ContractState, to: ContractAddress, quantity: u256
        ) -> Span<u256> {
            self.safe_batch_mint(to, quantity)
        }

        fn safeBatchMintWithURIs(
            ref self: ContractState, to: ContractAddress, uris: Span<ByteArray>
        ) -> Span<u256> {
            self.safe_batch_mint_with_uris(to, uris)
        }
    }


    #[abi(embed_v0)]
    impl IOpenMarNFTkMetadataCamelOnlyImpl of IOpenMarkNFTMetadataCamel<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.om_erc721.token_uri(tokenId)
        }
    }

    #[abi(embed_v0)]
    impl IOpenMarkSRC5Impl of ISRC5<ContractState> {
        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            self.erc721.supports_interface(interface_id)
        }
    }
}
