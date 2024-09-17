use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    start_cheat_caller_address, map_entry_address, start_cheat_block_timestamp, load,
};

use openmark::{
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait},
    core::interface::{
         IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait
    },
    core::interface::{
        IOpenMarkManagerDispatcher, IOpenMarkManagerDispatcherTrait
    },
};
use openmark::tests::unit::common::{create_offer, create_buy, create_mock_hasher, ZERO};
use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;

#[test]
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

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, openmark_address);

    openmark.buy(seller, order, signature);
    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);

    assert(nft_dispatcher.owner_of(order.tokenId.into())== buyer, 'NFT owner not correct');
    assert(buyer_after_balance== buyer_before_balance - order.price.into(), 'Buyer balance not correct');
    assert(seller_after_balance==seller_before_balance + order.price.into(), 'Seller balance not correct');
}

#[test]
fn cancel_buy_works() {
    let (order, signature, openmark_address, _, _, seller, _) = create_buy();

    start_cheat_caller_address(openmark_address, seller);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.cancel_order(order, signature);
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array(signature);

    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span(),),
        1,
    );

    assert(*usedSignatures.at(0) == true.into(), 'Cancel order failed');
}

#[test]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn buy_invalid_signature_len_panics() {
    let (order, _, openmark_address, _, payment_token, seller, buyer,) = create_buy();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    openmark.buy(seller, order, array![].span());
}

#[test]
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
#[should_panic(expected: ('OPENMARK: invalid order type',))]
fn buy_invalid_order_type_panics() {
    let (order, signature, openmark_address, _, _, seller, buyer) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark.verify_buy(order, signature, seller, buyer);
}

#[test]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn buy_seller_is_zero_panics() {
    let (order, signature, openmark_address, _, _, _, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verify_buy(order, signature, ZERO(), buyer);
}

#[test]
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
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn buy_price_is_zero_panics() {
    let (mut order, signature, openmark_address, _, _, seller, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    order.price = 0;
    openmark.verify_buy(order, signature, seller, buyer);
}

#[test]
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
