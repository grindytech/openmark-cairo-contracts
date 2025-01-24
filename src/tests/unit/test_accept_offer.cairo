use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc1155::interface::{IERC1155DispatcherTrait, IERC1155Dispatcher};

use snforge_std::{start_cheat_caller_address, map_entry_address, start_cheat_block_timestamp, load};

use openmark::{
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait},
    core::interface::{IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait}
};
use openmark::tests::unit::common::{create_offer, create_offer_with_value, create_mock_hasher, create_buy, ZERO};
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
    openmark.accept_offer(buyer, order, signature);

    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);

    assert(nft_dispatcher.owner_of(order.tokenId.into()) == buyer, 'NFT owner not correct');
    assert(
        buyer_after_balance == buyer_before_balance - order.price.into(),
        'Buyer balance not correct'
    );
    assert(
        seller_after_balance== seller_before_balance + order.price.into(), 'Seller balance not correct'
    );
}

#[test]
fn accept_offer_with_value_works() {
    let (order, signature, openmark_address, nft_token, payment_token, seller, buyer) =
    create_offer_with_value();

    // buy and verify
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, seller);

    start_cheat_caller_address(payment_token, buyer);
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    payment_dispatcher.approve(openmark_address, 1000);

    let nft_dispatcher = IERC1155Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(nft_token, openmark_address);
    start_cheat_caller_address(openmark_address, seller);

    openmark.accept_offer_with_value(buyer, order, 5, signature);
    assert(
        payment_dispatcher.balance_of(buyer) == buyer_before_balance - (order.price.into() * 5),
        'Buyer balance not correct'
    );
    assert(
        payment_dispatcher.balance_of(seller) == seller_before_balance + (order.price.into() * 5),
        'Seller balance not correct'
    );
    assert(nft_dispatcher.balance_of(buyer, order.tokenId.into()) == 5, 'NFT owner not correct');
    
    openmark.accept_offer_with_value(buyer, order, 5, signature);
    assert(
        payment_dispatcher.balance_of(buyer) == buyer_before_balance - (order.price.into() * 10),
        'Buyer balance not correct'
    );
    assert(
        payment_dispatcher.balance_of(seller) == seller_before_balance + (order.price.into() * 10),
        'Seller balance not correct'
    );
    assert(nft_dispatcher.balance_of(buyer, order.tokenId.into()) == 10, 'NFT owner not correct');
}


#[test]
fn cancel_offer_works() {
    let (order, signature, openmark_address, _, _, _, buyer) = create_offer();

    start_cheat_caller_address(openmark_address, buyer);

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.cancel_order(order, signature);
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array(signature);

    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span(),),
        1,
    );

    assert(*usedSignatures.at(0)== true.into(), 'Cancel order failed');
}


#[test]
#[should_panic(expected: ('OM: invalid sig len',))]
fn order_invalid_signature_len_panics() {
    let (order, _, openmark_address, _, payment_token, seller, buyer,) = create_offer();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.accept_offer(buyer, order, array![].span());
}

#[test]
#[should_panic(expected: ('OM: sig used',))]
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
#[should_panic(expected: ('OM: order expired',))]
fn order_order_expired_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer,) = create_offer();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    openmark.accept_offer(buyer, order, signature);
}

#[test]
#[should_panic(expected: ('OM: invalid order type',))]
fn order_invalid_order_type_panics() {
    let (order, signature, openmark_address, _, _, seller, buyer,) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verifyAcceptOffer(order, signature, seller, buyer,);
}

#[test]
#[should_panic(expected: ('OM: address is zero',))]
fn order_seller_is_zero_panics() {
    let (order, signature, openmark_address, _, _, _, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.verifyAcceptOffer(order, signature, ZERO(), buyer,);
}
