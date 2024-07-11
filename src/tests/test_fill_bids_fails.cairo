use core::array::SpanTrait;
use core::traits::Into;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openmark::interface::IOM721TokenDispatcherTrait;
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, map_entry_address,
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy,
    start_cheat_block_timestamp
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::{Order, Bid, OrderType, SignedBid},
    interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOM721TokenDispatcher,
    },
    openmark::OpenMark::Event as OpenMarkEvent, openmark::OpenMark::{validate_bids, validate_order},
    events::{OrderFilled, OrderCancelled, BidCancelled}, errors as Errors,
};
use openmark::tests::common::{
    create_offer, create_bids, deploy_erc721_at, deploy_openmark, TEST_ETH_ADDRESS,
    TEST_ERC721_ADDRESS, TEST_SELLER, TEST_BUYER1, TEST_BUYER2, TEST_BUYER3,
    get_contract_state_for_testing, ZERO
};

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn fill_bids_invalid_signature_len_panics() {
    let (
        mut signed_bids,
        _bids,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();
    let mut bids = array![new_bid, *signed_bids.at(1), *signed_bids.at(2)];
    OpenMarkDispatcher.fill_bids(bids.span(), erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn fill_bids_signature_used_panics() {
    let (
        signed_bids,
        bids,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, *buyers.at(0));
    OpenMarkDispatcher.cancel_bid(*bids.at(0), *signed_bids.at(0).signature);

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    OpenMarkDispatcher.fill_bids(signed_bids, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig',))]
fn fill_bids_invalid_signature_panics() {
    let (
        mut signed_bids,
        _bids,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![1, 2].span();
    let mut bids = array![new_bid, *signed_bids.at(1), *signed_bids.at(2)];
    OpenMarkDispatcher.fill_bids(bids.span(), erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: too many bids',))]
fn fill_bids_too_many_bids_panics() {
    let (
        signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut bids = array![];

    let mut i = 0_u32;
    while i < 11 {
        bids.append(*signed_bids.at(0));
        i += 1;
    };

    let mut state = get_contract_state_for_testing();
    validate_bids(@state, bids.span(), seller, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn fill_bids_seller_is_zero_panics() {
    let (
        mut signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.bidder = ZERO();
    let mut bids = array![new_bid];
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, bids.span(), seller, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: no bids',))]
fn fill_bids_no_bids_panics() {
    let (
        _signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    let mut bids = array![];
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, bids.span(), seller, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: zero bids amount',))]
fn fill_bids_zero_amount_panics() {
    let (
        mut signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.amount = 0;
    let mut bids = array![new_bid];
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, bids.span(), seller, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn fill_bids_zero_price_panics() {
    let (
        mut signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.unitPrice = 0;
    let mut bids = array![new_bid];
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, bids.span(), seller, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: asking too high',))]
fn fill_bids_asking_price_too_high_panics() {
    let (
        signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, signed_bids, seller, erc721_address, tokenIds, unitPrice + 1);
}


#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig expired',))]
fn fill_bids_sig_expired_panics() {
    let (
        signed_bids,
        bids,
        OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    start_cheat_block_timestamp(openmark_address, (*bids.at(0)).expiry.try_into().unwrap());

    // let mut state = get_contract_state_for_testing();
    OpenMarkDispatcher.fill_bids(signed_bids, erc721_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: nft mismatch',))]
fn fill_bids_nft_mismatch_panics() {
    let (
        signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        _erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut state = get_contract_state_for_testing();

    validate_bids(@state, signed_bids, seller, eth_address, tokenIds, unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: exceed bid nfts',))]
fn fill_bids_exceed_bid_nfts_panics() {
    let (
        signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        _tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_tokenIds = array![0, 1, 2, 3, 4, 5, 6];

    let mut state = get_contract_state_for_testing();
    validate_bids(@state, signed_bids, seller, erc721_address, new_tokenIds.span(), unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: not enough nfts',))]
fn fill_bids_not_enough_nfts_panics() {
    let (
        signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        _ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        _tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);

    let mut new_tokenIds = array![0, 1, 2];
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, signed_bids, seller, erc721_address, new_tokenIds.span(), unitPrice);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: seller not owner',))]
fn fill_bids_seller_not_owner_panics() {
    let (
        signed_bids,
        _bids,
        _OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        _ERC20Dispatcher,
        eth_address,
        seller,
        _buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    start_cheat_caller_address(erc721_address, seller);
    ERC721Dispatcher.transfer_from(seller, 1.try_into().unwrap(), 0);

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(eth_address, openmark_address);
    let mut state = get_contract_state_for_testing();
    validate_bids(@state, signed_bids, seller, erc721_address, tokenIds, unitPrice);
}

