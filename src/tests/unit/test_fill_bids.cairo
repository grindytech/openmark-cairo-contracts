use core::result::ResultTrait;
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
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address,
    start_cheat_account_contract_address, spy_events, EventSpy, EventSpyAssertionsTrait,
    start_cheat_block_timestamp, Event
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::types::{OrderType},
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark,},
    core::interface::{
        IOpenMarkProvider, IOpenMarkProviderDispatcher, IOpenMarkProviderDispatcherTrait
    },
    core::interface::{
        IOpenMarkManager, IOpenMarkManagerDispatcher, IOpenMarkManagerDispatcherTrait
    },
    core::openmark::OpenMark::{InternalImplTrait},
    core::OpenMark::Event as OpenMarkEvent, core::events::{BidFilled, BidCancelled},
    core::errors as Errors,
};

use openmark::tests::unit::common::{
    create_buy, create_offer, create_bids, ZERO, create_mock_hasher, do_create_nft, deploy_erc20,
    get_contract_state_for_testing
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

    assert_eq!(nft_dispatcher.owner_of(0), *buyers.at(0));
    assert_eq!(nft_dispatcher.owner_of(1), *buyers.at(1));
    assert_eq!(nft_dispatcher.owner_of(2), *buyers.at(1));
    assert_eq!(nft_dispatcher.owner_of(3), *buyers.at(2));
    assert_eq!(nft_dispatcher.owner_of(4), *buyers.at(2));
    assert_eq!(nft_dispatcher.owner_of(5), *buyers.at(2));

    assert_eq!(seller_after_balance, seller_before_balance + (unitPrice.into() * 6));

    assert_eq!(buyer1_after_balance, buyer1_before_balance - unitPrice.into());
    assert_eq!(buyer2_after_balance, buyer2_before_balance - (unitPrice.into() * 2));
    assert_eq!(buyer3_after_balance, buyer3_before_balance - (unitPrice.into() * 3));

    // // events
    // let expected_event1 = OpenMarkEvent::BidFilled(
    //     BidFilled {
    //         seller,
    //         bidder: *buyers.at(0),
    //         bid: (*signed_bids.at(0)).bid,
    //         tokenIds: array![0].span(),
    //     }
    // );
    // let expected_event2 = OpenMarkEvent::BidFilled(
    //     BidFilled {
    //         seller,
    //         bidder: *buyers.at(1),
    //         bid: (*signed_bids.at(1)).bid,
    //         tokenIds: array![1, 2].span(),
    //     }
    // );
    // let expected_event3 = OpenMarkEvent::BidFilled(
    //     BidFilled {
    //         seller,
    //         bidder: *buyers.at(2),
    //         bid: (*signed_bids.at(2)).bid,
    //         tokenIds: array![3, 4, 5].span(),
    //     }
    // );
    // spy
    //     .assert_emitted(
    //         @array![
    //             (openmark_address, expected_event1),
    //             (openmark_address, expected_event2),
    //             (openmark_address, expected_event3)
    //         ]
    //     );
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

    assert_eq!(nft_dispatcher.owner_of(0), *buyers.at(0));
    assert_eq!(nft_dispatcher.owner_of(1), *buyers.at(1));
    assert_eq!(nft_dispatcher.owner_of(2), *buyers.at(1));
    assert_eq!(nft_dispatcher.owner_of(3), *buyers.at(2));
    assert_eq!(nft_dispatcher.owner_of(4), *buyers.at(2));

    assert_eq!(seller_after_balance, seller_before_balance + (unitPrice.into() * 5));

    assert_eq!(buyer1_after_balance, buyer1_before_balance - unitPrice.into());
    assert_eq!(buyer2_after_balance, buyer2_before_balance - (unitPrice.into() * 2));
    assert_eq!(buyer3_after_balance, buyer3_before_balance - (unitPrice.into() * 2));
    let hasher = create_mock_hasher();
    let hash_sig: felt252 = hasher.hash_array((*signed_bids.at(2)).signature);
    let partialBidSignatures = load(
        openmark_address,
        map_entry_address(selector!("partialBidSignatures"), array![hash_sig].span()),
        1,
    );
    assert_eq!((*partialBidSignatures.at(0)).try_into().unwrap(), 1_u128);

    openmark
        .fill_bids(
            array![*signed_bids.at(2)].span(), nft_token, array![5].span(), payment_token, unitPrice
        );

    assert_eq!(nft_dispatcher.owner_of(5), *buyers.at(2));

    let seller_after_balance = payment_dispatcher.balance_of(seller);
    let buyer3_after_balance = payment_dispatcher.balance_of(*buyers.at(2));
    assert_eq!(seller_after_balance, seller_before_balance + (unitPrice.into() * 6));
    assert_eq!(buyer3_after_balance, buyer3_before_balance - (unitPrice.into() * 3));

    let partialBidSignatures = load(
        openmark_address,
        map_entry_address(selector!("partialBidSignatures"), array![hash_sig].span()),
        1,
    );
    assert_eq!((*partialBidSignatures.at(0)).try_into().unwrap(), 0_u128);
    let usedSignatures = load(
        openmark_address,
        map_entry_address(selector!("usedSignatures"), array![hash_sig].span()),
        1,
    );
    assert_eq!(*usedSignatures.at(0), true.into());
}


#[test]
fn cancel_bid_works() {
    let (mut signed_bids, openmark_address, _, _, _, buyers, _) = create_bids();

    {
        start_cheat_caller_address(openmark_address, *buyers.at(0));
        // let mut spy = spy_events();
        let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
        let hasher = create_mock_hasher();
        let hash_sig: felt252 = hasher.hash_array(*signed_bids.at(0).signature);

        openmark.cancel_bid(*signed_bids.at(0).bid, *signed_bids.at(0).signature);

        let usedSignatures = load(
            openmark_address,
            map_entry_address(selector!("usedSignatures"), array![hash_sig].span(),),
            1,
        );

        assert_eq!(*usedSignatures.at(0), true.into());
        // events
        let expected_event = OpenMarkEvent::BidCancelled(
            BidCancelled { who: *buyers.at(0), bid: (*signed_bids.at(0)).bid }
        );
        // spy.assert_emitted(@array![(openmark_address, expected_event)]);
    }
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

    assert_eq!(result, Result::Err(Errors::ZERO_NFTS));
}

#[test]
fn fill_bids_seller_is_zero() {
    let (mut signed_bids, _, nft_token, _, _, _, token_ids,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();

    let result = InternalImplTrait::_verify_bid_seller(
        @get_contract_state_for_testing(), ZERO(), nft_token, token_ids
    );

    assert_eq!(result, Result::Err(Errors::ZERO_ADDRESS));
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

    assert_eq!(result, Result::Err(Errors::NOT_NFT_OWNER));
}


#[test]
fn fill_bids_invalid_signature_len() {
    let (mut signed_bids, _, _, _, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();

    let result = InternalImplTrait::_verify_bid_signature(
        @get_contract_state_for_testing(), new_bid.bid, new_bid.bidder, new_bid.signature
    );

    assert_eq!(result, Result::Err(Errors::INVALID_SIGNATURE_LEN));
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

    assert_eq!(result, Result::Err(Errors::SIGNATURE_USED));
}


#[test]
fn fill_bids_buyer_is_zero() {
    let (mut signed_bids, _, _, _, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    let result = InternalImplTrait::_verify_bid(
        @get_contract_state_for_testing(), new_bid.bid, ZERO()
    );

    assert_eq!(result, Result::Err(Errors::ZERO_ADDRESS));
}


#[test]
fn fill_bids_invalid_payment() {
    let (mut signed_bids, _, nft_token, _, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.payment = nft_token;
    let mut state = get_contract_state_for_testing();

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert_eq!(result, Result::Err(Errors::INVALID_PAYMENT_TOKEN));
}

#[test]
fn fill_bids_zero_amount() {
    let (mut signed_bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.amount = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert_eq!(result, Result::Err(Errors::ZERO_BIDS_AMOUNT));
}

#[test]
fn fill_bids_zero_price() {
    let (mut signed_bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *signed_bids.at(0);
    new_bid.bid.unitPrice = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert_eq!(result, Result::Err(Errors::PRICE_IS_ZERO));
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

    assert_eq!(result, Result::Err(Errors::INSUFFICIENT_BALANCE));
}

#[test]
fn fill_bids_bid_expired() {
    let (bids, _, _, payment_token, _, _, _,) = create_bids();

    let mut new_bid = *bids.at(0);
    new_bid.bid.expiry = 0;

    let mut state = get_contract_state_for_testing();
    state.paymentTokens.write(payment_token, true);

    let result = InternalImplTrait::_verify_bid(@state, new_bid.bid, new_bid.bidder,);

    assert_eq!(result, Result::Err(Errors::BID_EXPIRED));
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

    assert_eq!(result, Result::Err(Errors::NFT_MISMATCH));
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

    assert_eq!(result, Result::Err(Errors::PAYMENT_MISMATCH));
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

    assert_eq!(result, Result::Err(Errors::ASKING_PRICE_TOO_HIGH));
}

