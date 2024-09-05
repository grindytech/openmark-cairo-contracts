use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    start_cheat_caller_address, map_entry_address,start_cheat_block_timestamp, load
};

use openmark::{
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait},
    core::interface::{
        IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait
    },
    core::OpenMark::Event as OpenMarkEvent, core::events::{OrderFilled, OrderCancelled},
};
use openmark::tests::unit::common::{create_offer, create_mock_hasher, create_buy, ZERO};
use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;

#[test]
fn accept_offer_works() {
    let (order, signature, openmark_address, nft_token, payment_token, seller, buyer) =
        create_offer();
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };

    // buy and verify
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);
    // let mut spy = spy_events();

    openmark.accept_offer(buyer, order, signature);

    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);

    assert_eq!(nft_dispatcher.owner_of(order.tokenId.into()), buyer);
    assert_eq!(buyer_after_balance, buyer_before_balance - order.price.into());
    assert_eq!(seller_after_balance, seller_before_balance + order.price.into());

    // events
    let _expected_event = OpenMarkEvent::OrderFilled(OrderFilled { seller, buyer, order });
    //  spy.assert_emitted(
    //         @array![
    //             (openmark_address, expected_event),
    //         ]
    //     );
}


#[test]
fn cancel_offer_works() {
    let (order, signature, openmark_address, _, _, _, buyer) = create_offer();

    start_cheat_caller_address(openmark_address, buyer);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    // let mut spy = spy_events();

    openmark.cancel_order(order, signature);
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array(signature);

    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span(),),
        1,
    );

    assert_eq!(*usedSignatures.at(0), true.into());

    // events
    let _expected_event = OpenMarkEvent::OrderCancelled(OrderCancelled { who: buyer, order });
    //  spy.assert_emitted(
    //         @array![
    //             (openmark_address, expected_event),
    //         ]
    //     );
}


#[test]

#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn order_invalid_signature_len_panics() {
    let (order, _, openmark_address, _, payment_token, seller, buyer,) = create_offer();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.accept_offer(buyer, order, array![].span());
}

#[test]

#[should_panic(expected: ('OPENMARK: sig used',))]
fn order_signature_used_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer,) = create_offer();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    openmark.cancel_order(order, signature);

    start_cheat_caller_address(openmark_address, seller);
    openmark.accept_offer(buyer, order, signature);
}

#[test]

#[should_panic(expected: ('OPENMARK: order expired',))]
fn order_order_expired_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer,) = create_offer();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    openmark.accept_offer(buyer, order, signature);
}

#[test]

#[should_panic(expected: ('OPENMARK: invalid order type',))]
fn order_invalid_order_type_panics() {
    let (order, signature, openmark_address, _, _, seller, buyer,) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verify_accept_offer(order, signature, seller, buyer,);
}

#[test]

#[should_panic(expected: ('OPENMARK: address is zero',))]
fn order_seller_is_zero_panics() {
    let (order, signature, openmark_address, _, _, _, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verify_accept_offer(order, signature, ZERO(), buyer,);
}

#[test]

#[should_panic(expected: ('OPENMARK: not nft owner',))]
fn order_seller_not_owner_panics() {
    let (order, signature, openmark_address, nft_token, _, seller, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };

    start_cheat_caller_address(nft_token, seller);
    nft_dispatcher.transfer_from(seller, buyer, order.tokenId.into());

    openmark.verify_accept_offer(order, signature, seller, buyer,);
}

#[test]

#[should_panic(expected: ('OPENMARK: price is zero',))]
fn order_price_is_zero_panics() {
    let (mut order, signature, openmark_address, _, _, seller, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    order.price = 0;
    openmark.verify_accept_offer(order, signature, seller, buyer,);
}
