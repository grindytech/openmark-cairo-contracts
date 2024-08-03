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
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy,
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
    core::OpenMark::Event as OpenMarkEvent, core::events::{BidFilled, BidCancelled},
    core::errors as Errors, core::OpenMark::{InternalImpl},
};

use openmark::tests::unit::common::{
    create_buy, create_offer, create_bids, ZERO, create_mock_hasher, do_create_nft,
    deploy_erc20
};
use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;

#[test]
#[available_gas(2000000)]
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

    let mut spy = spy_events(SpyOn::One(openmark_address));

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

    // events
    let expected_event1 = OpenMarkEvent::BidFilled(
        BidFilled {
            seller,
            bidder: *buyers.at(0),
            bid: (*signed_bids.at(0)).bid,
            tokenIds: array![0].span(),
        }
    );
    let expected_event2 = OpenMarkEvent::BidFilled(
        BidFilled {
            seller,
            bidder: *buyers.at(1),
            bid: (*signed_bids.at(1)).bid,
            tokenIds: array![1, 2].span(),
        }
    );
    let expected_event3 = OpenMarkEvent::BidFilled(
        BidFilled {
            seller,
            bidder: *buyers.at(2),
            bid: (*signed_bids.at(2)).bid,
            tokenIds: array![3, 4, 5].span(),
        }
    );
    spy
        .assert_emitted(
            @array![
                (openmark_address, expected_event1),
                (openmark_address, expected_event2),
                (openmark_address, expected_event3)
            ]
        );
}

#[test]
#[available_gas(2000000)]
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
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: no bids',))]
fn fill_bids_no_bids_panics() {
    let (_, openmark_address, nft_token, payment_token, seller, _, _,) = create_bids();

    start_cheat_caller_address(openmark_address, seller);
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    openmark.fill_bids(array![].span(), nft_token, array![].span(), payment_token, 0);
}

#[test]
#[available_gas(2000000)]
fn cancel_bid_works() {
    let (mut signed_bids, openmark_address, _, _, _, buyers, _) = create_bids();

    {
        start_cheat_caller_address(openmark_address, *buyers.at(0));
        let mut spy = spy_events(SpyOn::One(openmark_address));
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
        spy.assert_emitted(@array![(openmark_address, expected_event)]);
    }
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: invalid sig len',))]
fn fill_bids_invalid_signature_len_panics() {
    let (mut signed_bids, openmark_address, nft_token, payment_token, seller, _, tokenIds,) =
        create_bids();

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let mut new_bid = *signed_bids.at(0);
    new_bid.signature = array![].span();
    let mut bids = array![new_bid, *signed_bids.at(1), *signed_bids.at(2)];
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    openmark
        .fill_bids(
            bids.span(), nft_token, tokenIds, payment_token, *signed_bids.at(0).bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: sig used',))]
fn fill_bids_signature_used_panics() {
    let (mut signed_bids, openmark_address, nft_token, payment_token, seller, buyers, tokenIds) =
        create_bids();
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    start_cheat_caller_address(openmark_address, *buyers.at(0));
    openmark.cancel_bid(*signed_bids.at(0).bid, *signed_bids.at(0).signature);

    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    openmark
        .fill_bids(
            signed_bids, nft_token, tokenIds, payment_token, *signed_bids.at(0).bid.unitPrice
        );
}


#[test]
#[available_gas(2000000)]
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
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn fill_bids_seller_is_zero_panics() {
    let (bids, openmark_address, nft_token, payment_token, _, _, token_ids,) = create_bids();

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark
        .verify_fill_bids(
            bids, ZERO(), nft_token, token_ids, payment_token, *bids.at(0).bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: address is zero',))]
fn fill_bids_buyer_is_zero_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    let mut new_bid = *bids.at(0);
    new_bid.bidder = ZERO();

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark
        .verify_fill_bids(
            array![new_bid].span(),
            seller,
            nft_token,
            token_ids,
            payment_token,
            new_bid.bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: not nft owner',))]
fn fill_bids_seller_not_owner_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();
    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    start_cheat_caller_address(nft_token, seller);

    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    nft_dispatcher.transfer_from(seller, 1.try_into().unwrap(), 0);

    openmark
        .verify_fill_bids(
            bids, seller, nft_token, token_ids, payment_token, *bids.at(0).bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: Invalid payment token',))]
fn fill_bids_invalid_payment_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    start_cheat_caller_address(openmark_address, seller);
    let manager = IOpenMarkManagerDispatcher { contract_address: openmark_address };
    manager.remove_payment_token(payment_token);

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark
        .verify_fill_bids(
            bids, seller, nft_token, token_ids, payment_token, *bids.at(0).bid.unitPrice
        );
}


#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: zero bids amount',))]
fn fill_bids_zero_amount_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut new_bid = *bids.at(0);
    new_bid.bid.amount = 0;

    openmark
        .verify_fill_bids(
            array![new_bid].span(),
            seller,
            nft_token,
            token_ids,
            payment_token,
            new_bid.bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: price is zero',))]
fn fill_bids_zero_price_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    let mut new_bid = *bids.at(0);
    new_bid.bid.unitPrice = 0;

    openmark
        .verify_fill_bids(
            array![new_bid].span(),
            seller,
            nft_token,
            token_ids,
            payment_token,
            *bids.at(0).bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: insufficient balance',))]
fn fill_bids_insufficient_balance_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    let mut new_bid = *bids.at(0);

    start_cheat_caller_address(payment_token, new_bid.bidder);
    let payment = IERC20Dispatcher { contract_address: payment_token };
    payment.transfer(openmark_address, payment.balance_of(new_bid.bidder));

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark
        .verify_fill_bids(
            bids, seller, nft_token, token_ids, payment_token, *bids.at(0).bid.unitPrice
        );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: bid expired',))]
fn fill_bids_bid_expired_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    let new_bid = *bids.at(0);

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

    start_cheat_block_timestamp(openmark_address, new_bid.bid.expiry.try_into().unwrap());
    openmark
        .verify_fill_bids(
            bids, seller, nft_token, token_ids, payment_token, *bids.at(0).bid.unitPrice
        );
}

// #[test]
// #[available_gas(2000000)]
// #[should_panic(expected: ('OPENMARK: nft mismatch',))]
// fn fill_bids_nft_mismatch_panics() {
//     let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

//     let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };

//     openmark
//         .verify_fill_bids(
//             bids, seller, payment_token, token_ids, payment_token, *bids.at(0).bid.unitPrice
//         );
// }

// #[test]
// #[available_gas(2000000)]
// #[should_panic(expected: ('OPENMARK: payment mismatch',))]
// fn fill_bids_payment_mismatch_panics() {
//     let (bids, openmark_address, nft_token, _, seller, _, token_ids,) = create_bids();

//     let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
//     let new_payment = deploy_erc20();

//     openmark
//         .verify_fill_bids(
//             bids, seller, nft_token, token_ids, new_payment, *bids.at(0).bid.unitPrice
//         );
// }

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('OPENMARK: asking too high',))]
fn fill_bids_asking_too_high_panics() {
    let (bids, openmark_address, nft_token, payment_token, seller, _, token_ids,) = create_bids();

    let openmark = IOpenMarkProviderDispatcher { contract_address: openmark_address };
    openmark
        .verify_fill_bids(
            bids, seller, nft_token, token_ids, payment_token, *bids.at(0).bid.unitPrice + 1
        );
}

