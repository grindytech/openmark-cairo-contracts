use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, map_entry_address,
    start_cheat_block_timestamp, spy_events, SpyOn, EventSpy, EventAssertions, load
};

use starknet::{ContractAddress};

use openmark::{
    primitives::types::{OrderType},
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark},
    core::interface::{
        IOpenMarkProvider, IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait
    },
    core::interface::{
        IOpenMarkManager, IOpenMarkManagerDispatcher, IOpenMarkManagerDispatcherTrait
    },
    core::OpenMark::Event as OpenMarkEvent, core::events::{OrderFilled, OrderCancelled},
    core::errors as Errors,
};
use openmark::tests::unit::common::{create_offer, create_buy, create_mock_hasher, ZERO};
use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;

#[test]
#[available_gas(2000000)]
fn buy_works() {
    let (order, signature, openmark_address, nft_token, payment_token, seller, buyer) =
        create_buy();

    // buy and verify
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, seller);

    start_cheat_caller_address(payment_token, buyer);
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    payment_dispatcher.approve(openmark_address, order.price.try_into().unwrap());

    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);
    let mut spy = spy_events(SpyOn::One(openmark_address));

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, openmark_address);

    openmark.buy(seller, order, signature);
    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);

    assert_eq!(nft_dispatcher.owner_of(order.tokenId.into()), buyer);
    assert_eq!(buyer_after_balance, buyer_before_balance - order.price.into());
    assert_eq!(seller_after_balance, seller_before_balance + order.price.into());

    // events
    let expected_event = OpenMarkEvent::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
fn cancel_buy_works() {
    let (order, signature, openmark_address, _, _, seller, _) = create_buy();

    start_cheat_caller_address(openmark_address, seller);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let mut spy = spy_events(SpyOn::One(openmark_address));

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
    let expected_event = OpenMarkEvent::OrderCancelled(OrderCancelled { who: seller, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn buy_invalid_signature_len_panics() {
    let (order, _, openmark_address, _, payment_token, seller, buyer,) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    openmark.buy(seller, order, array![].span());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn buy_signature_used_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer,) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(payment_token, buyer);
    start_cheat_caller_address(openmark_address, seller);
    openmark.cancel_order(order, signature);

    start_cheat_caller_address(openmark_address, buyer);
    openmark.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: order expired',))]
fn buy_order_expired_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer,) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    openmark.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid order type',))]
fn buy_invalid_order_type_panics() {
    let (order, signature, openmark_address, _, _, seller, buyer) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark.verify_buy(order, signature, seller, buyer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn buy_seller_is_zero_panics() {
    let (order, signature, openmark_address, _, _, _, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verify_buy(order, signature, ZERO(), buyer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: not nft owner',))]
fn buy_seller_not_owner_panics() {
    let (order, signature, openmark_address, nft_token, _, seller, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(nft_token, seller);
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    nft_dispatcher.transfer_from(seller, buyer, order.tokenId.into());

    openmark.verify_buy(order, signature, seller, buyer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn buy_price_is_zero_panics() {
    let (mut order, signature, openmark_address, _, _, seller, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    order.price = 0;
    openmark.verify_buy(order, signature, seller, buyer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: Invalid payment token',))]
fn invalid_payment_token_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer) = create_buy();
    let openmark = IOpenMarkManagerDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, seller);
    openmark.remove_payment_token(payment_token);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    openmark.buy(seller, order, signature);
}
