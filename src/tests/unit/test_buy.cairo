use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc1155::interface::{IERC1155DispatcherTrait, IERC1155Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    start_cheat_caller_address, map_entry_address, start_cheat_block_timestamp, load, spy_events,
};
use snforge_std::EventSpyAssertionsTrait;

use openmark::{
    core::interface::{
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMarkManagerDispatcher,
        IOpenMarkManagerDispatcherTrait,
    },
    core::interface::{IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait},
};
use openmark::tests::unit::common::{
    create_offer, create_buy, create_buy_with_value, create_mock_hasher, ZERO, OM_OWNER, toAddress,
    ROYALTY, NFT_OWNER,
};
use openmark::core::OpenMark;
use openmark::primitives::constants::{PERMYRIAD};
use openmark::core::events::{OrderFilled, OrderCancelled};
use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;

#[test]
fn buy_works() {
    let (order, signature, openmark_address, nft_token, payment_token, seller, buyer) =
        create_buy();
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
    openmark.buy(seller, order, signature);
    let expected_event = OpenMark::Event::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let owner_balance = payment_dispatcher.balance_of(toAddress(OM_OWNER));
    let nft_owner_balance = payment_dispatcher.balance_of(toAddress(NFT_OWNER));

    let price: u256 = (order.price * order.value).into();
    let commission = price * commission / PERMYRIAD;
    let royalty = price * ROYALTY / PERMYRIAD;
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

#[test]
fn buy_with_value_works() {
    let (order, signature, openmark_address, nft_token, payment_token, seller, buyer) =
        create_buy_with_value();
    let COMMISSION = 500; // 5%
    // setup commission and royalty
    let manager_dispatcher = IOpenMarkManagerDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(openmark_address, toAddress(OM_OWNER));
    manager_dispatcher.set_commission(COMMISSION);

    // buy and verify
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, seller);

    start_cheat_caller_address(payment_token, buyer);
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    payment_dispatcher.approve(openmark_address, order.price.into() * order.value.into());

    let nft_dispatcher = IERC1155Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(nft_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);

    let mut spy = spy_events();
    let value = 5;
    openmark.buy_with_value(seller, order, value, signature);
    let expected_event = OpenMark::Event::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
    let owner_balance = payment_dispatcher.balance_of(toAddress(OM_OWNER));
    let nft_owner_balance = payment_dispatcher.balance_of(toAddress(NFT_OWNER));

    let price: u256 = (order.price * value).into();
    let commission = price * COMMISSION / PERMYRIAD;
    let royalty = price * ROYALTY / PERMYRIAD;
    let payout = price - commission - royalty;

    assert(
        payment_dispatcher.balance_of(buyer) == buyer_before_balance - price,
        'Buyer balance not correct',
    );
    assert(
        payment_dispatcher.balance_of(seller) == seller_before_balance + payout,
        'Seller balance not correct',
    );
    assert(nft_dispatcher.balance_of(buyer, order.tokenId.into()) == 5, 'NFT owner not correct');
    assert(owner_balance == commission, 'OM Owner balance not correct');
    assert(nft_owner_balance == royalty, 'royalty not correct');

    openmark.buy_with_value(seller, order, value, signature);
    let owner_balance = payment_dispatcher.balance_of(toAddress(OM_OWNER));
    let nft_owner_balance = payment_dispatcher.balance_of(toAddress(NFT_OWNER));

    let price: u256 = (order.price * value * 2).into();
    let commission = price * COMMISSION / PERMYRIAD;
    let royalty = price * ROYALTY / PERMYRIAD;
    let payout = price - commission - royalty;

    assert(
        payment_dispatcher.balance_of(buyer) == buyer_before_balance - price,
        '2 Buyer balance not correct',
    );

    assert(
        payment_dispatcher.balance_of(seller) == seller_before_balance + payout,
        '2 Seller balance not correct',
    );

    assert(nft_dispatcher.balance_of(buyer, order.tokenId.into()) == 10, 'NFT owner not
correct');

    assert(owner_balance == commission, '2 OM Owner balance not correct');
    assert(nft_owner_balance == royalty, '2 royalty not correct');
}

#[test]
fn cancel_buy_works() {
    let (order, signature, openmark_address, _, _, seller, _) = create_buy();

    start_cheat_caller_address(openmark_address, seller);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let mut spy = spy_events();
    openmark.cancel_order(order, signature);
    let expected_event = OpenMark::Event::OrderCancelled(
        OrderCancelled { who: seller, order: order },
    );
    spy.assert_emitted(@array![(openmark_address, expected_event)]);

    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array(signature);

    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span()),
        1,
    );

    assert(*usedSignatures.at(0) == true.into(), 'Cancel order failed');
}

#[test]
#[should_panic(expected: ('OM: invalid sig len',))]
fn buy_invalid_signature_len_panics() {
    let (order, _, openmark_address, _, payment_token, seller, buyer) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    openmark.buy(seller, order, array![].span());
}

#[test]
#[should_panic(expected: ('OM: sig used',))]
fn buy_signature_used_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(payment_token, buyer);
    start_cheat_caller_address(openmark_address, seller);
    openmark.cancel_order(order, signature);

    start_cheat_caller_address(openmark_address, buyer);
    openmark.buy(seller, order, signature);
}

#[test]
#[should_panic(expected: ('OM: order expired',))]
fn buy_order_expired_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    openmark.buy(seller, order, signature);
}

#[test]
#[should_panic(expected: ('OM: invalid order type',))]
fn buy_invalid_order_type_panics() {
    let (order, signature, openmark_address, _, _, seller, buyer) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark.verifyBuy(order, signature, seller, buyer);
}

#[test]
#[should_panic(expected: ('OM: address is zero',))]
fn buy_seller_is_zero_panics() {
    let (order, signature, openmark_address, _, _, _, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verifyBuy(order, signature, ZERO(), buyer);
}
