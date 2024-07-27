use openmark::hasher::interface::IOffchainMessageHashDispatcherTrait;
use core::array::SpanTrait;
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::TryInto;

use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;

use snforge_std::signature::SignerTrait;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, load, map_entry_address, spy_events,
    SpyOn, EventAssertions, EventSpy, Event, start_cheat_block_timestamp,
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::types::{OrderType, Bid},
    core::interface::{IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark},
    core::OpenMark::Event as OpenMarkEvent,
    core::events::{OrderFilled, BidFilled, OrderCancelled, BidCancelled}, core::errors as Errors,
};
use openmark::tests::unit::common::{
    create_buy, create_offer, create_bids, ZERO, create_mock_hasher
};

#[test]
#[available_gas(2000000)]
fn buy_works() {
    let (order, signature, openmark_address, nft_token, payment_token, seller, buyer) =
        create_buy();

    // buy and verify
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, seller);

    start_cheat_caller_address(payment_token, buyer);
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    payment_dispatcher.approve(openmark_address, order.price.try_into().unwrap());

    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    let buyer_before_balance = payment_dispatcher.balance_of(buyer);
    let seller_before_balance = payment_dispatcher.balance_of(seller);
    let mut spy = spy_events(SpyOn::One(openmark_address));

    start_cheat_caller_address(payment_token, openmark_address);
    start_cheat_caller_address(openmark_address, buyer);
    start_cheat_caller_address(nft_token, openmark_address);

    openmark.buy(seller, order, signature);
    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);

    assert_eq!(nft_dispatcher.owner_of(order.tokenId.into()), buyer);
    assert_eq!(buyer_after_balance, buyer_before_balance - order.price.into());
    assert_eq!(seller_after_balance, seller_before_balance + order.price.into());

    // events
    let expected_event = OpenMarkEvent::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
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
    let mut spy = spy_events(SpyOn::One(openmark_address));

    openmark.accept_offer(buyer, order, signature);

    let buyer_after_balance = payment_dispatcher.balance_of(buyer);
    let seller_after_balance = payment_dispatcher.balance_of(seller);

    assert_eq!(nft_dispatcher.owner_of(order.tokenId.into()), buyer);
    assert_eq!(buyer_after_balance, buyer_before_balance - order.price.into());
    assert_eq!(seller_after_balance, seller_before_balance + order.price.into());

    // events
    let expected_event = OpenMarkEvent::OrderFilled(OrderFilled { seller, buyer, order });
    spy.assert_emitted(@array![(openmark_address, expected_event)]);
}

#[test]
#[available_gas(2000000)]
fn cancel_order_works() {
    let (order, signature, openmark_address, _, _, seller, _) = create_buy();

    {
        start_cheat_caller_address(openmark_address, seller);

        let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

        let mut spy = spy_events(SpyOn::One(openmark_address));

        openmark.cancel_order(order, signature);
        let hasher = create_mock_hasher();
        let hash_sig: felt252 = hasher.hash_array(signature);

        let usedSignatures = load(
            openmark_address,
            map_entry_address(selector!("usedSignatures"), array![hash_sig].span(),),
            1,
        );

        assert_eq!(*usedSignatures.at(0), true.into());

        // events
        let expected_event = OpenMarkEvent::OrderCancelled(OrderCancelled { who: seller, order });
        spy.assert_emitted(@array![(openmark_address, expected_event)]);
    }
}

#[test]
#[available_gas(2000000)]
fn fill_bids_works() {
    let (
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };

    // accept bids and verify
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let seller_before_balance = payment_dispatcher.balance_of(seller);
    let buyer1_before_balance = payment_dispatcher.balance_of(*buyers.at(0));
    let buyer2_before_balance = payment_dispatcher.balance_of(*buyers.at(1));
    let buyer3_before_balance = payment_dispatcher.balance_of(*buyers.at(2));

    let mut spy = spy_events(SpyOn::One(openmark_address));

    openmark.fill_bids(signed_bids, nft_token, tokenIds, unitPrice);

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
        mut signed_bids,
        openmark_address,
        nft_token,
        payment_token,
        seller,
        buyers,
        mut tokenIds,
        unitPrice
    ) =
        create_bids();
    let payment_dispatcher = IERC20Dispatcher { contract_address: payment_token };
    let nft_dispatcher = IERC721Dispatcher { contract_address: nft_token };
    let openmark = IOpenMarkDispatcher { contract_address: openmark_address };
    // accept bids and verify
    start_cheat_caller_address(openmark_address, seller);
    start_cheat_caller_address(payment_token, openmark_address);

    let seller_before_balance = payment_dispatcher.balance_of(seller);
    let buyer1_before_balance = payment_dispatcher.balance_of(*buyers.at(0));
    let buyer2_before_balance = payment_dispatcher.balance_of(*buyers.at(1));
    let buyer3_before_balance = payment_dispatcher.balance_of(*buyers.at(2));

    let _ = tokenIds.pop_back();
    openmark.fill_bids(signed_bids, nft_token, tokenIds, unitPrice);

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
        .fill_bids(array![*signed_bids.at(2)].span(), nft_token, array![5].span(), unitPrice);

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
fn cancel_bid_works() {
    let (mut signed_bids, openmark_address, _, _, _, buyers, _, _) = create_bids();

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
