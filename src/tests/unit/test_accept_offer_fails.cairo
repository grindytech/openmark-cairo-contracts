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
    core::OpenMark::Event as OpenMarkEvent, core::events::{OrderFilled, OrderCancelled},
    core::errors as Errors,
};
use openmark::tests::unit::common::{create_offer, create_buy, ZERO};


#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn order_invalid_signature_len_panics() {
    let (order, _, openmark_address, _, eth_address, seller, buyer,) = create_offer();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.accept_offer(buyer, order, array![].span());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn order_signature_used_panics() {
    let (order, signature, openmark_address, _, eth_address, seller, buyer,) = create_offer();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(eth_address, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    openmark.cancel_order(order, signature);

    start_cheat_caller_address(openmark_address, seller);
    openmark.accept_offer(buyer, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig expired',))]
fn order_sig_expired_panics() {
    let (order, signature, openmark_address, _, eth_address, seller, buyer,) = create_offer();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    openmark.accept_offer(buyer, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid order type',))]
fn order_invalid_order_type_panics() {
    let (order, _, openmark_address, _, _, seller, buyer,) = create_buy();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.validate_order(order, seller, buyer, OrderType::Offer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn order_seller_is_zero_panics() {
    let (order, _, openmark_address, _, _, _, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.validate_order(order, ZERO(), buyer, OrderType::Offer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: seller not owner',))]
fn order_seller_not_owner_panics() {
    let (order, _, openmark_address, erc721_address, _, seller, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    let nft_dispatcher = IERC721Dispatcher { contract_address: erc721_address };

    start_cheat_caller_address(erc721_address, seller);
    nft_dispatcher.transfer_from(seller, buyer, order.tokenId.into());

    openmark.validate_order(order, seller, buyer, OrderType::Offer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn order_price_is_zero_panics() {
    let (mut order, _, openmark_address, _, _, seller, buyer,) = create_offer();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    order.price = 0;
    openmark.validate_order(order, seller, buyer, OrderType::Offer);
}
