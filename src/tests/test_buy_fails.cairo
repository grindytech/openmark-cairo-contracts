use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::interface::IOM721TokenDispatcherTrait;
use openzeppelin::tests::utils::constants::{OWNER, ZERO};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy,
    start_cheat_block_timestamp
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::{Order, Bid, OrderType, SignedBid},
    interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOM721TokenDispatcher
    },
    openmark::OpenMark::Event as OpenMarkEvent,
    events::{OrderFilled, OrderCancelled, BidsFilled, BidCancelled}, errors as Errors,
};
use openmark::tests::common::{
    create_buy, create_offer, create_bids, deploy_erc721_at, deploy_openmark, TEST_ETH_ADDRESS,
    TEST_ERC721_ADDRESS, TEST_SELLER, TEST_BUYER1, TEST_BUYER2, TEST_BUYER3,
};

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig expired',))]
fn buy_sig_expired_panics() {
    let (
        order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    OpenMarkDispatcher.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid order type',))]
fn buy_invalid_order_type_panics() {
    let (
        mut order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    order.option = OrderType::Offer;
    OpenMarkDispatcher.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn buy_seller_is_zero_panics() {
    let (
        order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        _seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);
    OpenMarkDispatcher.buy(ZERO(), order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: seller not owner',))]
fn buy_seller_not_owner_panics() {
    let (
        order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(erc721_address, seller);
    ERC721Dispatcher.transfer_from(seller, buyer, order.tokenId.into());
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    OpenMarkDispatcher.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn buy_price_is_zero_panics() {
    let (
        mut order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    order.price = 0;
    OpenMarkDispatcher.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn buy_invalid_signature_len_panics() {
    let (
        order,
        _signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    OpenMarkDispatcher.buy(seller, order, array![].span());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn buy_signature_used_panics() {
    let (
        order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(eth_address, buyer);
    start_cheat_caller_address(openmark_address, seller);
    OpenMarkDispatcher.cancel_order(order, signature);

    start_cheat_caller_address(openmark_address, buyer);
    OpenMarkDispatcher.buy(seller, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig',))]
fn buy_invalid_signature_panics() {
    let (
        order,
        _signature,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(eth_address, buyer);

    OpenMarkDispatcher.buy(seller, order, array![1,2].span());
}