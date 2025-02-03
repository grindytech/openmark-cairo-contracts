#[starknet::contract]
pub mod OpenCollection {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;

    use openmark::launchpad::stage::StageComponent;
    use openmark::launchpad::interface::IStageSelector;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    use openmark::primitives::types::{Stage};
    use openmark::primitives::constants::{PERMYRIAD};
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address
    };
    use openmark::launchpad::errors::LPErrors as Errors;
    use openmark::launchpad::events::{
        TokensBought,
    };

    component!(path: StageComponent, storage: ostage, event: OStageEvent);

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    /// Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl OStageImpl = StageComponent::OStageImpl<ContractState>;
    impl OStageInternalImpl = StageComponent::InternalImpl<ContractState>;

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ostage: StageComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OStageEvent: StageComponent::Event,
        TokensBought: TokensBought,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        stage: Stage,
        commission: u128,
        commissionReceiver: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.ostage.initializer(stage, commission, commissionReceiver);
    }


    #[abi(embed_v0)]
    impl StageSelector of IStageSelector<ContractState> {
        fn buy(
            ref self: ContractState,
            tokenIds: Span<u256>,
            values: Option<Span<u256>>,
            merkleProof: Span<felt252>
        ) {
            // Make sure stage is valid
            self.validateStage();

            let mintAmount = tokenIds.len().into();
            assert(mintAmount > 0, Errors::ZERO_MINT_AMOUNT);

            let minter: ContractAddress = get_caller_address();

            let stageMintedAmount = self.ostage.stageMintedCount.read();
            let userMintedAmount = self.ostage.userMintedCount.read(minter);

            assert(
                stageMintedAmount + mintAmount <= self.ostage.stage.maxAllocation.read(),
                Errors::SOLD_OUT
            );
            assert(
                userMintedAmount + mintAmount <= self.ostage.stage.limit.read(),
                Errors::EXCEED_LIMIT
            );

            self.validateWhitelist(minter, merkleProof);

            self.ostage.stageMintedCount.write(stageMintedAmount + mintAmount);
            self.ostage.userMintedCount.write(minter, userMintedAmount + mintAmount);

            // Implement Mint here
            {

            }

            let price = mintAmount * self.ostage.stage.price.read();
            let token_dispatcher = IERC20Dispatcher { contract_address: self.ostage.stage.payment.read() };
            token_dispatcher.transfer_from(minter, get_contract_address(), price.into());

            self
                .emit(
                    TokensBought {
                        buyer: minter,
                        amount: mintAmount,
                        paymentToken: self.ostage.stage.payment.read(),
                        price: self.ostage.stage.price.read(),
                    }
                );
        }
    }
}
