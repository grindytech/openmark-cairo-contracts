#[starknet::contract]
mod OERC1155 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::ContractAddress;

    use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openmark::primitives::constants::{MINTER_ROLE};
    use openmark::assets::errors::Errors;

    use openmark::assets::interface::{IERC1155Minter};

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
        totalSupply: u256,
        royaltyPercentage: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        uri: ByteArray,
        totalSupply: u256,
        royaltyPercentage: u256
    ) {
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);
        self.erc1155.initializer(uri);
        self.totalSupply.write(totalSupply);
        self.royaltyPercentage.write(royaltyPercentage);
    }


    #[abi(embed_v0)]
    impl ERC1155MinterImpl of IERC1155Minter<ContractState> {
        fn mint(
            ref self: ContractState,
            to: ContractAddress,
            tokenId: u256,
            value: u256,
            data: Span<felt252>
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            assert(tokenId < self.totalSupply.read(), Errors::INVALID_TOKEN_ID);

            self.erc1155.mint_with_acceptance_check(to, tokenId, value, data);
        }

        fn mintBatch(
            ref self: ContractState,
            to: ContractAddress,
            tokenIds: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            for tokenId in tokenIds {
                assert(*tokenId < self.totalSupply.read(), Errors::INVALID_TOKEN_ID);
            };
            self.erc1155.batch_mint_with_acceptance_check(to, tokenIds, values, data);
        }
    }
}
