use core::array::SpanTrait;
use core::traits::Into;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{start_cheat_caller_address, load, map_entry_address};

use openmark::{
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait},
    core::interface::{IOpenMarkManagerDispatcher, IOpenMarkManagerDispatcherTrait},
    core::openmark::OpenMark::{InternalImplTrait}, core::OpenMark::Event as OpenMarkEvent,
    core::events::{BidCancelled}, core::errors::OMErrors as Errors,
};

use openmark::tests::unit::common::{
    create_bids, ZERO, create_mock_hasher, get_contract_state_for_testing
};
use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;

#[test]
fn fill_bids_works() {
    let (mut signed_bids, openmark_address, nft_token, payment_token, seller, buyers, tokenIds) =
        create_bids();
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    let unitPrice = (*signed_bids.at(0)).bid.unitPrice;

    // accept bids and verify
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let seller_before_balance = payment_dispatcher.balance_of(seller);
    let buyer1_before_balance = payment_dispatcher.balance_of(*buyers.at(0));
    let buyer2_before_balance = payment_dispatcher.balance_of(*buyers.at(1));
    let buyer3_before_balance = payment_dispatcher.balance_of(*buyers.at(2));

    // let mut spy = spy_events();
    openmark.fill_bids(signed_bids, nft_token, tokenIds, payment_token, unitPrice);

    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let buyer1_after_balance = payment_dispatcher.balance_of(*buyers.at(0));
    let buyer2_after_balance = payment_dispatcher.balance_of(*buyers.at(1));
    let buyer3_after_balance = payment_dispatcher.balance_of(*buyers.at(2));

    assert(nft_dispatcher.owner_of(0) == *buyers.at(0), 'NFT owner not correct');
    assert(nft_dispatcher.owner_of(1) == *buyers.at(1), 'NFT owner not correct');
    assert(nft_dispatcher.owner_of(2) == *buyers.at(1), 'NFT owner not correct');
    assert(nft_dispatcher.owner_of(3) == *buyers.at(2), 'NFT owner not correct');
    assert(nft_dispatcher.owner_of(4) == *buyers.at(2), 'NFT owner not correct');
    assert(nft_dispatcher.owner_of(5) == *buyers.at(2), 'NFT owner not correct');

    assert(
        seller_after_balance == seller_before_balance + (unitPrice.into() * 6),
        'Seller balance not correct'
    );
    assert(
        buyer1_after_balance == buyer1_before_balance - unitPrice.into(),
        'Buyer balance not correct'
    );
    assert(
        buyer2_after_balance == buyer2_before_balance - (unitPrice.into() * 2),
        'Buyer balance not correct'
    );
    assert(
        buyer3_after_balance == buyer3_before_balance - (unitPrice.into() * 3),
        'Buyer balance not correct'
    );
}

#[test]
fn fill_bids_partial_works() {
    let (
        mut signed_bids, openmark_address, nft_token, payment_token, seller, buyers, mut tokenIds
    ) =
        create_bids();
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    let unitPrice = (*signed_bids.at(0)).bid.unitPrice;

    // accept bids and verify
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let seller_before_balance = payment_dispatcher.balance_of(seller);
    let buyer1_before_balance = payment_dispatcher.balance_of(*buyers.at(0));
    let buyer2_before_balance = payment_dispatcher.balance_of(*buyers.at(1));
    let buyer3_before_balance = payment_dispatcher.balance_of(*buyers.at(2));

    let _ = tokenIds.pop_back();
    openmark.fill_bids(signed_bids, nft_token, tokenIds, payment_token, unitPrice);

    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let buyer1_after_balance = payment_dispatcher.balance_of(*buyers.at(0));
    let buyer2_after_balance = payment_dispatcher.balance_of(*buyers.at(1));
    let buyer3_after_balance = payment_dispatcher.balance_of(*buyers.at(2));

    assert(nft_dispatcher.owner_of(0) == *buyers.at(0),'NFT owner not correct');
    assert(nft_dispatcher.owner_of(1) == *buyers.at(1),'NFT owner not correct');
    assert(nft_dispatcher.owner_of(2) == *buyers.at(1),'NFT owner not correct');
    assert(nft_dispatcher.owner_of(3) == *buyers.at(2),'NFT owner not correct');
    assert(nft_dispatcher.owner_of(4) == *buyers.at(2),'NFT owner not correct');

    assert(seller_after_balance== seller_before_balance + (unitPrice.into() * 5), 'Seller balance not correct');
    assert(buyer1_after_balance== buyer1_before_balance - unitPrice.into(), 'Buyer balance not correct');
    assert(buyer2_after_balance== buyer2_before_balance - (unitPrice.into() * 2), 'Buyer balance not correct');
    assert(buyer3_after_balance== buyer3_before_balance - (unitPrice.into() * 2), 'Buyer balance not correct');
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array((*signed_bids.at(2)).signature);
    let partialBidSignatures = load(
        openmark_address,
        map_entry_address(selector!("partialBidSignatures"), array![hash_sig].span()),
        1,
    );
    assert((*partialBidSignatures.at(0)).try_into().unwrap() == 1_u128, 'Partial signature not correct');

    openmark
        .fill_bids(
            array![*signed_bids.at(2)].span(), nft_token, array![5].span(), payment_token, unitPrice
        );

    assert(nft_dispatcher.owner_of(5) == *buyers.at(2), 'NFT owner not correct');

    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let buyer3_after_balance = payment_dispatcher.balance_of(*buyers.at(2));
    assert(seller_after_balance == seller_before_balance + (unitPrice.into() * 6), 'Seller balance not correct');
    assert(buyer3_after_balance == buyer3_before_balance - (unitPrice.into() * 3), 'Buyer balance not correct');

    let partialBidSignatures = load(
        openmark_address,
        map_entry_address(selector!("partialBidSignatures"), array![hash_sig].span()),
        1,
    );
    assert((*partialBidSignatures.at(0)).try_into().unwrap() == 0_u128, 'Partial signature not coorect');
    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span()),
        1,
    );
    assert(*usedSignatures.at(0) == true.into(), 'Signature must be used');
}


#[test]
fn cancel_bid_works() {
    let (mut signed_bids, openmark_address, _, _, _, buyers, _) = create_bids();

    start_cheat_caller_address(openmark_address, *buyers.at(0));
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array(*signed_bids.at(0).signature);

    openmark.cancel_bid(*signed_bids.at(0).bid, *signed_bids.at(0).signature);

    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span(),),
        1,
    );

    assert(*usedSignatures.at(0)== true.into(), 'Signature must be used');
    // events
    let _expected_event = OpenMarkEvent::BidCancelled(
        BidCancelled { who: *buyers.at(0), bid: (*signed_bids.at(0)).bid }
    );
}


#[test]
#[should_panic(expected: ('OPENMARK: no valid bids',))]
fn fill_bids_no_valid_bids_panics() {
    let (_, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    start_cheat_caller_address(openmark_address, seller);
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.fill_bids(array![].span(), nft_token, token_ids, payment_token, 0);
}


#[test]
#[should_panic(expected: ('OPENMARK: too many nfts',))]
fn fill_bids_too_many_nft_panics() {
    let (mut signed_bids, openmark_address, nft_token, payment_token, seller, _, tokenIds) =
        create_bids();

    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    let openmark_manager = IOpenMarkManagerDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, seller);
    openmark_manager.set_max_fill_nfts(1);

    openmark
        .fill_bids(
            signed_bids, nft_token, tokenIds, payment_token, *signed_bids.at(0).bid.unitPrice
        );
}

#[test]
fn fill_bids_zero_nfts() {
    let (mut signed_bids, _, nft_token, _, seller, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();

    let result = InternalImplTrait::_verify_bid_seller(
        @get_contract_state_for_testing(), seller, nft_token, array![].span()
    );

    assert(result == Result::Err(Errors::ZERO_NFTS), 'Verify bid failed');
}

#[test]
fn fill_bids_seller_is_zero() {
    let (mut signed_bids, _, nft_token, _, _, _, token_ids,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();

    let result = InternalImplTrait::_verify_bid_seller(
        @get_contract_state_for_testing(), ZERO(), nft_token, token_ids
    );

    assert(result== Result::Err(Errors::ZERO_ADDRESS), 'Verify bid failed');
}

#[test]
fn fill_bids_seller_not_owner() {
    let (bids, _, nft_token, _, seller, _, token_ids,) = create_bids();

    start_cheat_caller_address(nft_token, seller);
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    nft_dispatcher.transfer_from(seller, 1.try_into().unwrap(), 0);

    let mut new_bid = *bids.at(0);
    new_bid.signature = array![].span();

    let result = InternalImplTrait::_verify_bid_seller(
        @get_contract_state_for_testing(), seller, nft_token, token_ids
    );

    assert(result== Result::Err(Errors::NOT_NFT_OWNER), 'Verify bid failed');
}


#[test]
fn fill_bids_invalid_signature_len() {
    let (mut signed_bids, _, _, _, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();

    let result = InternalImplTrait::_verify_bid_signature(
        @get_contract_state_for_testing(), new_bid.bid, new_bid.bidder, new_bid.signature
    );

    assert(result== Result::Err(Errors::INVALID_SIGNATURE_LEN), 'Verify bid failed');
}

#[test]
fn fill_bids_signature_used() {
    let (mut signed_bids, openmark_address, _, _, _, _, _) = create_bids();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    let mut new_bid = *signed_bids.at(0);

    start_cheat_caller_address(openmark_address, new_bid.bidder);
    openmark.cancel_bid(new_bid.bid, new_bid.signature);

    let mut state = get_contract_state_for_testing();
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array(new_bid.signature);

    state.usedSignatures.write(hash_sig, true);

    let result = InternalImplTrait::_verify_bid_signature(
        @state, new_bid.bid, new_bid.bidder, new_bid.signature
    );

    assert(result== Result::Err(Errors::SIGNATURE_USED), 'Verify bid failed');
}


#[test]
fn fill_bids_buyer_is_zero() {
    let (mut signed_bids, _, _, _, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    let result = InternalImplTrait::_verify_bid(
        @get_contract_state_for_testing(), new_bid.bid, ZERO()
    );

    assert(result== Result::Err(Errors::ZERO_ADDRESS), 'Verify bid failed');
}


#[test]
fn fill_bids_invalid_payment() {
    let (mut signed_bids, _, nft_token, _, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.payment = nft_token;
    let mut state = get_contract_state_for_testing();

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert(result== Result::Err(Errors::INVALID_PAYMENT_TOKEN), 'Verify bid failed');
}

#[test]
fn fill_bids_zero_amount() {
    let (mut signed_bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.amount = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert(result== Result::Err(Errors::ZERO_BIDS_AMOUNT), 'Verify bid failed');
}

#[test]
fn fill_bids_zero_price() {
    let (mut signed_bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.unitPrice = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert(result== Result::Err(Errors::PRICE_IS_ZERO), 'Verify bid failed');
}

#[test]
fn fill_bids_insufficient_balance() {
    let (bids, openmark_address, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *bids.at(0);

    start_cheat_caller_address(payment_token, new_bid.bidder);
    let payment = IERC20Dispatcher { contract_address: payment_token };
    payment.transfer(openmark_address, payment.balance_of(new_bid.bidder));

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert(result== Result::Err(Errors::INSUFFICIENT_BALANCE), 'Verify bid failed');
}

#[test]
fn fill_bids_bid_expired() {
    let (bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *bids.at(0);
    new_bid.bid.expiry = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert(result== Result::Err(Errors::BID_EXPIRED), 'Verify bid failed');
}

#[test]
fn fill_bids_nft_mismatch() {
    let (bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *bids.at(0);
    new_bid.bid.unitPrice = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_matching_bid(
        @state, new_bid.bid, payment_token, payment_token, new_bid.bid.unitPrice
    );

    assert(result== Result::Err(Errors::NFT_MISMATCH), 'Verify matching failed');
}

#[test]
fn fill_bids_payment_mismatch() {
    let (bids, _, nft_token, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *bids.at(0);
    new_bid.bid.unitPrice = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_matching_bid(
        @state, new_bid.bid, nft_token, nft_token, new_bid.bid.unitPrice
    );

    assert(result== Result::Err(Errors::PAYMENT_MISMATCH), 'Verify matching failed');
}

#[test]
fn fill_bids_asking_too_high() {
    let (bids, _, nft_token, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *bids.at(0);
    new_bid.bid.unitPrice = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_matching_bid(
        @state, new_bid.bid, nft_token, payment_token, new_bid.bid.unitPrice + 1
    );

    assert(result== Result::Err(Errors::ASKING_PRICE_TOO_HIGH), 'Verify matching failed');
}

