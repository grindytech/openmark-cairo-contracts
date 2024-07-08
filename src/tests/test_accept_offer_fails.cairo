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
    openmark::OpenMark::Event as OpenMarkEvent, openmark::OpenMark::{validate_order},
    events::{OrderFilled, OrderCancelled, BidCancelled}, errors as Errors,
};
use openmark::tests::common::{
    create_offer, create_buy, deploy_erc721_at, deploy_openmark, TEST_ETH_ADDRESS,
    TEST_ERC721_ADDRESS, TEST_SELLER, TEST_BUYER1, TEST_BUYER2, TEST_BUYER3,
    get_contract_state_for_testing,
};


#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn order_invalid_signature_len_panics() {
    let (order, _, OpenMarkDispatcher, openmark_address, _, _, _, eth_address, seller, buyer,) =
        create_offer();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    OpenMarkDispatcher.accept_offer(buyer, order, array![].span());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn order_signature_used_panics() {
    let (
        order, signature, OpenMarkDispatcher, openmark_address, _, _, _, eth_address, seller, buyer,
    ) =
        create_offer();

    start_cheat_caller_address(eth_address, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    OpenMarkDispatcher.cancel_order(order, signature);

    start_cheat_caller_address(openmark_address, seller);
    OpenMarkDispatcher.accept_offer(buyer, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig',))]
fn order_invalid_signature_panics() {
    let (order, _, OpenMarkDispatcher, openmark_address, _, _, _, eth_address, seller, buyer,) =
        create_offer();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    OpenMarkDispatcher.accept_offer(buyer, order, array![1, 2].span());
}


#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig expired',))]
fn order_sig_expired_panics() {
    let (
        order, signature, OpenMarkDispatcher, openmark_address, _, _, _, eth_address, seller, buyer,
    ) =
        create_offer();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    start_cheat_block_timestamp(openmark_address, order.expiry.try_into().unwrap());
    OpenMarkDispatcher.accept_offer(buyer, order, signature);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid order type',))]
fn order_invalid_order_type_panics() {
    let (mut order, _, _, _, _, _, _, _, seller, buyer,) = create_buy();

    let mut state = get_contract_state_for_testing();
    validate_order(@state, order, seller, buyer, OrderType::Offer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn order_seller_is_zero_panics() {
    let (order, _, _, _, _, _, _, _, _, buyer,) = create_offer();

    let mut state = get_contract_state_for_testing();
    validate_order(@state, order, ZERO(), buyer, OrderType::Offer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: seller not owner',))]
fn order_seller_not_owner_panics() {
    let (order, _, _, _, ERC721Dispatcher, erc721_address, _, _, seller, buyer,) = create_offer();

    start_cheat_caller_address(erc721_address, seller);
    ERC721Dispatcher.transfer_from(seller, buyer, order.tokenId.into());

    let mut state = get_contract_state_for_testing();
    validate_order(@state, order, seller, buyer, OrderType::Offer);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn order_price_is_zero_panics() {
      let (mut order, _, _, _, _, _, _, _, seller, buyer,) = create_offer();

    order.price = 0;
    let mut state = get_contract_state_for_testing();
    validate_order(@state, order, seller, buyer, OrderType::Offer);
}
