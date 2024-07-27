use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, map_entry_address,
    start_cheat_block_timestamp
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
use openmark::tests::unit::common::{create_offer, create_buy, ZERO};

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
#[should_panic(expected: ('OPENMARK: sig expired',))]
fn buy_sig_expired_panics() {
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
    let (order, _, openmark_address, _, _, seller, buyer) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark.validate_order(order, seller, buyer, OrderType::Buy);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn buy_seller_is_zero_panics() {
    let (order, _, openmark_address, _, _, _, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.validate_order(order, ZERO(), buyer, OrderType::Buy);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: seller not owner',))]
fn buy_seller_not_owner_panics() {
    let (order, _, openmark_address, nft_token, _, seller, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(nft_token, seller);
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    nft_dispatcher.transfer_from(seller, buyer, order.tokenId.into());

    openmark.validate_order(order, seller, buyer, OrderType::Buy);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn buy_price_is_zero_panics() {
    let (mut order, _, openmark_address, _, _, seller, buyer) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    order.price = 0;
    openmark.validate_order(order, seller, buyer, OrderType::Buy);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: Invalid payment token',))]
fn invalid_payment_token_panics() {
    let (order, signature, openmark_address, _, payment_token, seller, buyer) = create_buy();
    let openmark = IOpenMarkManagerDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, seller);
    openmark.remove_payment_tokens(array![payment_token].span());

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(payment_token, buyer);

    openmark.buy(seller, order, signature);
}
