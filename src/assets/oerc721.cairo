#[starknet::contract]
mod OERC721 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;
    use openmark::assets::interface::{IERC721Minter};

    use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openmark::primitives::constants::{MINTER_ROLE};

    use openmark::assets::errors::Errors;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);

    // Access Control
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlCamelImpl = AccessControlComponent::AccessControlCamelImpl<ContractState>;

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // self storage
        totalSupply: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        baseURI: ByteArray,
        totalSupply: u256,
        royaltyPercentage: u256
    ) {
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);
        self.erc721.initializer(name, symbol, baseURI);
    }


    #[abi(embed_v0)]
    impl ERC721MinterImpl of IERC721Minter<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, tokenId: u256) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            assert(tokenId < self.totalSupply.read(), Errors::INVALID_TOKEN_ID);

            self.erc721.mint(to, tokenId);
        }

        fn safe_mint(
            ref self: ContractState, to: ContractAddress, tokenId: u256, data: Span<felt252>
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            assert(tokenId < self.totalSupply.read(), Errors::INVALID_TOKEN_ID);

            self.erc721.safe_mint(to, tokenId, data);
        }

        fn safeMint(
            ref self: ContractState, to: ContractAddress, tokenId: u256, data: Span<felt252>
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            self.safe_mint(to, tokenId, data);
        }

        fn mintBatch(ref self: ContractState, to: ContractAddress, tokenIds: Span<u256>) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            for tokenId in tokenIds {
                self.mint(to, *tokenId);
            };
        }

        fn safeMintBatch(
            ref self: ContractState, to: ContractAddress, tokenIds: Span<u256>, data: Span<felt252>
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            for tokenId in tokenIds {
                self.safeMint(to, *tokenId, data);
            };
        }
    }
}
