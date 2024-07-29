use core::array::SpanTrait;
use core::traits::Into;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, map_entry_address,
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy,
    start_cheat_block_timestamp
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::types::{OrderType},
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark,},
    core::interface::{
        IOpenMarkProvider, IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait
    },
    core::OpenMark::Event as OpenMarkEvent,
    core::events::{OrderFilled, OrderCancelled, BidCancelled}, core::errors as Errors,
};
use openmark::tests::unit::common::{create_bids, get_contract_state_for_testing, ZERO,};

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn fill_bids_invalid_signature_len_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();
    let mut bids = array![new_bid, *signed_bids.at(1), *signed_bids.at(2)];
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    openmark.fill_bids(bids.span(), nft_token, tokenIds);
}
#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn fill_bids_signature_used_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        buyers,
        tokenIds,
        
    ) =
        create_bids();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, *buyers.at(0));
    openmark.cancel_bid(*signed_bids.at(0).bid, *signed_bids.at(0).signature);

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    openmark.fill_bids(signed_bids, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: too many bids',))]
fn fill_bids_too_many_bids_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();

    let mut bids = array![];

    let mut i = 0_u32;
    while i < 11 {
        bids.append(*signed_bids.at(0));
        i += 1;
    };

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.validate_bids(bids.span(), seller, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn fill_bids_seller_is_zero_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    let mut new_bid = *signed_bids.at(0);
    new_bid.bidder = ZERO();
    let mut bids = array![new_bid];
    openmark.validate_bids(bids.span(), seller, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: no bids',))]
fn fill_bids_no_bids_panics() {
    let (_, openmark_address, nft_token, payment_token, seller, _, tokenIds, ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut bids = array![];
    openmark.validate_bids(bids.span(), seller, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: zero bids amount',))]
fn fill_bids_zero_amount_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.amount = 0;
    let mut bids = array![new_bid];

    openmark.validate_bids(bids.span(), seller, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn fill_bids_zero_price_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.unitPrice = 0;
    let mut bids = array![new_bid];

    openmark.validate_bids(bids.span(), seller, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig expired',))]
fn fill_bids_sig_expired_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_block_timestamp(
        openmark_address, (*signed_bids.at(0)).bid.expiry.try_into().unwrap()
    );

    openmark.validate_bids(signed_bids, seller, nft_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: nft mismatch',))]
fn fill_bids_nft_mismatch_panics() {
    let (mut signed_bids, openmark_address, _, payment_token, seller, _, tokenIds, ) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    openmark.validate_bids(signed_bids, seller, payment_token, tokenIds, );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: exceed bid nfts',))]
fn fill_bids_exceed_bid_nfts_panics() {
    let (mut signed_bids, openmark_address, _, payment_token, seller, _, _) = create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut new_tokenIds = array![0, 1, 2, 3, 4, 5, 6];
    openmark.calculate_bid_amounts(signed_bids, new_tokenIds.span());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: not enough nfts',))]
fn fill_bids_not_enough_nfts_panics() {
    let (mut signed_bids, openmark_address, _, payment_token, seller, _, _) = create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut new_tokenIds = array![0, 1, 2];

    openmark.calculate_bid_amounts(signed_bids, new_tokenIds.span());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: seller not owner',))]
fn fill_bids_seller_not_owner_panics() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        _,
        tokenIds,
        
    ) =
        create_bids();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(nft_token, seller);

    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    nft_dispatcher.transfer_from(seller, 1.try_into().unwrap(), 0);

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    openmark.validate_bids(signed_bids, seller, nft_token, tokenIds, );
}

