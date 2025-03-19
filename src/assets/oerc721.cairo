#[starknet::contract]
mod OERC721 {
    use ERC721Component::InternalTrait as ERC721InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;
    use openzeppelin::token::common::erc2981::interface::{IERC2981};
    use openmark::assets::interface::{IERC721Minter, IOERC721Handler};

    use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openmark::primitives::constants::{MINTER_ROLE, PERMYRIAD};

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
        royaltyPercentage: u256,
        royaltyReceiver: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
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
        royaltyPercentage: u256,
    ) {
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);
        self.erc721.initializer(name, symbol, baseURI);
        self.totalSupply.write(totalSupply);
        self.royaltyPercentage.write(royaltyPercentage);
        self.royaltyReceiver.write(owner);
    }

    #[abi(embed_v0)]
    impl ERC721MinterImpl of IERC721Minter<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, tokenId: u256) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            assert(tokenId < self.totalSupply.read(), Errors::INVALID_TOKEN_ID);

            self.erc721.mint(to, tokenId);
        }

        fn safe_mint(
            ref self: ContractState, to: ContractAddress, tokenId: u256, data: Span<felt252>,
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            assert(tokenId < self.totalSupply.read(), Errors::INVALID_TOKEN_ID);

            self.erc721.safe_mint(to, tokenId, data);
        }

        fn mint_batch(ref self: ContractState, to: ContractAddress, tokenIds: Span<u256>) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            for tokenId in tokenIds {
                self.mint(to, *tokenId);
            };
        }

        fn safe_mint_batch(
            ref self: ContractState, to: ContractAddress, tokenIds: Span<u256>, data: Span<felt252>,
        ) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);

            for tokenId in tokenIds {
                self.safeMint(to, *tokenId, data);
            };
        }

        fn safeMint(
            ref self: ContractState, to: ContractAddress, tokenId: u256, data: Span<felt252>,
        ) {
            self.safe_mint(to, tokenId, data);
        }

        fn mintBatch(ref self: ContractState, to: ContractAddress, tokenIds: Span<u256>) {
            self.mint_batch(to, tokenIds);
        }

        fn safeMintBatch(
            ref self: ContractState, to: ContractAddress, tokenIds: Span<u256>, data: Span<felt252>,
        ) {
            self.safe_mint_batch(to, tokenIds, data);
        }
    }

    //**** Implement IOERC721Handler ****//
    #[abi(embed_v0)]
    impl OERC721HandlerImpl of IOERC721Handler<ContractState> {
        fn setBaseURI(ref self: ContractState, newBaseURI: ByteArray, newTotalSupply: u256) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            self.erc721._set_base_uri(newBaseURI);
            self.totalSupply.write(newTotalSupply);
        }
        fn BaseURI(self: @ContractState) -> ByteArray {
            self.erc721._base_uri()
        }
        fn getTotalSupply(self: @ContractState) -> u256 {
            self.totalSupply.read()
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
