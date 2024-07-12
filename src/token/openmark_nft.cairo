#[starknet::contract]
pub mod OpenMarkNFT {
    use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::access::ownable::OwnableComponent;

    use starknet::ContractAddress;
    use openmark::token::interface::IOM721Token;
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
        token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
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
        base_uri: ByteArray
    ) {
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol, base_uri);
        self.token_id.write(0);
    }

    #[abi(embed_v0)]
    impl OM721TokenImpl of IOM721Token<ContractState> {
        fn safe_mint(ref self: ContractState, to: ContractAddress) -> u256 {
            let token_id = next_token_id(ref self);
            self.erc721.mint(to, token_id);
            token_id
        }


        fn safe_batch_mint(
            ref self: ContractState, to: ContractAddress, quantity: u256
        ) -> Span<u256> {
            let mut token_ids = ArrayTrait::new();
            let mut i = 0;
            while i < quantity {
                let token_id = next_token_id(ref self);
                self.erc721.mint(to, token_id);
                token_ids.append(token_id);
                i += 1;
            };
            token_ids.span()
        }

        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.erc721._set_base_uri(base_uri);
        }

        fn get_base_uri(self: @ContractState) -> ByteArray {
            self.erc721._base_uri()
        }
    }


    /// Returns the current token_id and increments it for the next use.
    /// This ensures each token has a unique ID.
    fn next_token_id(ref self: ContractState) -> u256 {
        let current_token_id = self.token_id.read();
        self.token_id.write(current_token_id + 1);
        current_token_id
    }
}
