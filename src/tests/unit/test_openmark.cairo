use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use starknet::{ContractAddress};

use snforge_std::{spy_events};
use snforge_std::EventSpyAssertionsTrait;

use openmark::{
    core::interface::{
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMarkManagerDispatcher,
        IOpenMarkManagerDispatcherTrait,
    },
};
use openmark::assets::interface::{IOpenCollectionDispatcher, IOpenCollectionDispatcherTrait};

use openmark::tests::unit::common::{
    OM_OWNER, toAddress, NFT_OWNER, NFT_SYMBOL, NFT_NAME, TEST_NFT, SELLER1, BUYER1,
    setup_balance_at, TEST_PAYMENT, deploy_openmark,
};
use openmark::core::OpenMark;
use openmark::primitives::constants::{PERMYRIAD};
use openmark::primitives::types::{Order, OrderType};
use openmark::core::events::{OrderFilled};

pub fn setup_erc721_at(addr: ContractAddress, receiver: ContractAddress) -> ContractAddress {
    let contract = declare("OpenCollection").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append_serde(NFT_NAME());
    constructor_calldata.append_serde(NFT_SYMBOL());
    let (contract_address, _) = contract.deploy_at(@constructor_calldata, addr).unwrap();

    let collectionDispatcher = IOpenCollectionDispatcher { contract_address };
    collectionDispatcher.mintURIs(receiver, ["", "", "", ""].span());
    contract_address
}

#[test]
fn buy_works() {
    let payment_token = setup_balance_at(toAddress(TEST_PAYMENT));
    let seller: ContractAddress = toAddress(SELLER1);
    let nft_token = setup_erc721_at(toAddress(TEST_NFT), seller);
    let buyer: ContractAddress = toAddress(BUYER1);

    let openmark_address = deploy_openmark();
    let ERC721Dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let ERC20Dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let tokenId = 2;
    let order = Order {
        nftContract: nft_token,
        tokenId: tokenId,
        value: 1,
        payment: payment_token,
        price: 10000,
        salt: 4,
        expiry: 5,
        option: OrderType::Buy,
    };

    // create and approve
    {
        start_cheat_caller_address(nft_token, toAddress(NFT_OWNER));
        start_cheat_caller_address(nft_token, seller);
        ERC721Dispatcher.set_approval_for_all(openmark_address, true);
    }
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    ERC20Dispatcher.approve(openmark_address, 100000);
    let signature = array![
        0x36037f2776f6b844c80a863f09d635ac9464017193a668bede2e82cd8146303,
        0x570bbef96c0334beb61513f923d0ec45751e40baba45829f84fb0dba5202342,
    ];

    let commission = 500; // 5%
    // setup commission and royalty
    let manager_dispatcher = IOpenMarkManagerDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(openmark_address, toAddress(OM_OWNER));
    manager_dispatcher.set_commission(commission);

    // buy and verify
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, seller);

    start_cheat_caller_address(payment_token, buyer);
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };

    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, openmark_address);

    let mut spy = spy_events();
    openmark.buy(seller, order, signature.span());

    let expected_event = OpenMark::Event::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let owner_balance = payment_dispatcher.balance_of(toAddress(OM_OWNER));
    let nft_owner_balance = payment_dispatcher.balance_of(toAddress(NFT_OWNER));

    let price: u256 = (order.price * order.value).into();
    let commission = price * commission / PERMYRIAD;
    let royalty = 0;
    let payout = price - commission - royalty;

    assert(nft_dispatcher.owner_of(order.tokenId.into()) == buyer, 'NFT owner not correct');
    assert(
        buyer_after_balance == buyer_before_balance - order.price.into(),
        'Buyer balance not correct',
    );
    assert(seller_after_balance == seller_before_balance + payout, 'Seller balance not correct');
    assert(owner_balance == commission, 'commission not correct');
    assert(nft_owner_balance == royalty, 'royalty not correct');
}
