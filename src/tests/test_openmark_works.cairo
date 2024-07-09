use core::array::SpanTrait;
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
    start_cheat_account_contract_address, spy_events, SpyOn, EventAssertions, EventSpy, Event,
    start_cheat_block_timestamp,
};

use starknet::{ContractAddress, contract_address_const, get_tx_info, get_caller_address,};

use openmark::{
    primitives::{Order, Bid, OrderType, SignedBid},
    interface::{
        IOffchainMessageHashDispatcher, IOffchainMessageHashDispatcherTrait, IOffchainMessageHash,
        IOpenMarkDispatcher, IOpenMarkDispatcherTrait, IOpenMark, IOM721TokenDispatcher
    },
    openmark::OpenMark::Event as OpenMarkEvent,
    events::{OrderFilled, OrderCancelled, BidFilled, BidCancelled}, errors as Errors,
};
use openmark::tests::common::{
    create_buy, create_offer, create_bids, deploy_erc721_at, deploy_openmark, TEST_ETH_ADDRESS,
    TEST_ERC721_ADDRESS, TEST_SELLER, TEST_BUYER1, TEST_BUYER2, TEST_BUYER3, BID_SIGNATURES
};

#[test]
#[available_gas(2000000)]
fn buy_works() {
    let (
        order,
        signature,
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_buy();

    // buy and verify
    {
        start_cheat_caller_address(openmark_address, buyer);
        start_cheat_caller_address(eth_address, buyer);
        start_cheat_caller_address(erc721_address, seller);

        ERC20Dispatcher.approve(openmark_address, 3);

        let buyer_before_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_before_balance = ERC20Dispatcher.balance_of(seller);
        let mut spy = spy_events(SpyOn::One(openmark_address));

        OpenMarkDispatcher.buy(seller, order, signature);
        let buyer_after_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_after_balance = ERC20Dispatcher.balance_of(seller);

        assert_eq!(ERC721Dispatcher.owner_of(order.tokenId.into()), buyer);
        assert_eq!(buyer_after_balance, buyer_before_balance - order.price.into());
        assert_eq!(seller_after_balance, seller_before_balance + order.price.into());

        // events
        let expected_event = OpenMarkEvent::OrderFilled(OrderFilled { seller, buyer, order });
        spy.assert_emitted(@array![(openmark_address, expected_event)]);
    }
}


#[test]
#[available_gas(2000000)]
fn accept_offer_works() {
    let (
        order,
        signature,
        _OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        _erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        buyer,
    ) =
        create_offer();

    // buy and verify
    {
        start_cheat_caller_address(openmark_address, seller);
        start_cheat_caller_address(eth_address, openmark_address);

        let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };

        let buyer_before_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_before_balance = ERC20Dispatcher.balance_of(seller);
        let mut spy = spy_events(SpyOn::One(openmark_address));

        OpenMarkDispatcher.accept_offer(buyer, order, signature);

        let buyer_after_balance = ERC20Dispatcher.balance_of(buyer);
        let seller_after_balance = ERC20Dispatcher.balance_of(seller);

        assert_eq!(ERC721Dispatcher.owner_of(order.tokenId.into()), buyer);
        assert_eq!(buyer_after_balance, buyer_before_balance - order.price.into());
        assert_eq!(seller_after_balance, seller_before_balance + order.price.into());

        // events
        let expected_event = OpenMarkEvent::OrderFilled(OrderFilled { seller, buyer, order });
        spy.assert_emitted(@array![(openmark_address, expected_event)]);
    }
}


#[test]
#[available_gas(2000000)]
fn cancel_order_works() {
    let (order, signature, _, openmark_address, _, _, _, _, seller, _,) = create_buy();

    {
        start_cheat_caller_address(openmark_address, seller);

        let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };
        let mut spy = spy_events(SpyOn::One(openmark_address));

        OpenMarkDispatcher.cancel_order(order, signature);

        let usedSignatures = load(
            openmark_address, map_entry_address(selector!("usedSignatures"), signature,), 1,
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
        signed_bids,
        bids,
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        buyers,
        tokenIds,
        unitPrice
    ) =
        create_bids();

    // accept bids and verify
    {
        start_cheat_caller_address(openmark_address, seller);
        start_cheat_caller_address(eth_address, openmark_address);

        let seller_before_balance = ERC20Dispatcher.balance_of(seller);
        let buyer1_before_balance = ERC20Dispatcher.balance_of(*buyers.at(0));
        let buyer2_before_balance = ERC20Dispatcher.balance_of(*buyers.at(1));
        let buyer3_before_balance = ERC20Dispatcher.balance_of(*buyers.at(2));

        let mut spy = spy_events(SpyOn::One(openmark_address));

        OpenMarkDispatcher.fill_bids(signed_bids, erc721_address, tokenIds, unitPrice);

        let seller_after_balance = ERC20Dispatcher.balance_of(seller);
        let buyer1_after_balance = ERC20Dispatcher.balance_of(*buyers.at(0));
        let buyer2_after_balance = ERC20Dispatcher.balance_of(*buyers.at(1));
        let buyer3_after_balance = ERC20Dispatcher.balance_of(*buyers.at(2));

        assert_eq!(ERC721Dispatcher.owner_of(0), *buyers.at(0));
        assert_eq!(ERC721Dispatcher.owner_of(1), *buyers.at(1));
        assert_eq!(ERC721Dispatcher.owner_of(2), *buyers.at(1));
        assert_eq!(ERC721Dispatcher.owner_of(3), *buyers.at(2));
        assert_eq!(ERC721Dispatcher.owner_of(4), *buyers.at(2));
        assert_eq!(ERC721Dispatcher.owner_of(5), *buyers.at(2));

        assert_eq!(seller_after_balance, seller_before_balance + (unitPrice.into() * 6));

        assert_eq!(buyer1_after_balance, buyer1_before_balance - unitPrice.into());
        assert_eq!(buyer2_after_balance, buyer2_before_balance - (unitPrice.into() * 2));
        assert_eq!(buyer3_after_balance, buyer3_before_balance - (unitPrice.into() * 3));

        // events
        let expected_event1 = OpenMarkEvent::BidFilled(
            BidFilled {
                seller,
                bidder: *buyers.at(0),
                bid: *bids.at(0),
                tokenIds: array![0].span(),
                askingPrice: unitPrice
            }
        );
        let expected_event2 = OpenMarkEvent::BidFilled(
            BidFilled {
                seller,
                bidder: *buyers.at(1),
                bid: *bids.at(1),
                tokenIds: array![1, 2].span(),
                askingPrice: unitPrice
            }
        );
        let expected_event3 = OpenMarkEvent::BidFilled(
            BidFilled {
                seller,
                bidder: *buyers.at(2),
                bid: *bids.at(2),
                tokenIds: array![3, 4, 5].span(),
                askingPrice: unitPrice
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
}

#[test]
#[available_gas(2000000)]
fn fill_bids_partial_works() {
    let (
        signed_bids,
        _bids,
        OpenMarkDispatcher,
        openmark_address,
        ERC721Dispatcher,
        erc721_address,
        ERC20Dispatcher,
        eth_address,
        seller,
        buyers,
        mut tokenIds,
        unitPrice
    ) =
        create_bids();

    // accept bids and verify
    {
        start_cheat_caller_address(openmark_address, seller);
        start_cheat_caller_address(eth_address, openmark_address);

        let seller_before_balance = ERC20Dispatcher.balance_of(seller);
        let buyer1_before_balance = ERC20Dispatcher.balance_of(*buyers.at(0));
        let buyer2_before_balance = ERC20Dispatcher.balance_of(*buyers.at(1));
        let buyer3_before_balance = ERC20Dispatcher.balance_of(*buyers.at(2));

        let _ = tokenIds.pop_back();
        OpenMarkDispatcher.fill_bids(signed_bids, erc721_address, tokenIds, unitPrice);

        let seller_after_balance = ERC20Dispatcher.balance_of(seller);
        let buyer1_after_balance = ERC20Dispatcher.balance_of(*buyers.at(0));
        let buyer2_after_balance = ERC20Dispatcher.balance_of(*buyers.at(1));
        let buyer3_after_balance = ERC20Dispatcher.balance_of(*buyers.at(2));

        assert_eq!(ERC721Dispatcher.owner_of(0), *buyers.at(0));
        assert_eq!(ERC721Dispatcher.owner_of(1), *buyers.at(1));
        assert_eq!(ERC721Dispatcher.owner_of(2), *buyers.at(1));
        assert_eq!(ERC721Dispatcher.owner_of(3), *buyers.at(2));
        assert_eq!(ERC721Dispatcher.owner_of(4), *buyers.at(2));

        assert_eq!(seller_after_balance, seller_before_balance + (unitPrice.into() * 5));

        assert_eq!(buyer1_after_balance, buyer1_before_balance - unitPrice.into());
        assert_eq!(buyer2_after_balance, buyer2_before_balance - (unitPrice.into() * 2));
        assert_eq!(buyer3_after_balance, buyer3_before_balance - (unitPrice.into() * 2));

        let partialBidSignatures = load(
            openmark_address,
            map_entry_address(selector!("partialBidSignatures"), (*signed_bids.at(2)).signature,),
            1,
        );
        assert_eq!((*partialBidSignatures.at(0)).try_into().unwrap(), 1_u128);

        OpenMarkDispatcher
            .fill_bids(
                array![*signed_bids.at(2)].span(), erc721_address, array![5].span(), unitPrice
            );

        assert_eq!(ERC721Dispatcher.owner_of(5), *buyers.at(2));

        let seller_after_balance = ERC20Dispatcher.balance_of(seller);
        let buyer3_after_balance = ERC20Dispatcher.balance_of(*buyers.at(2));
        assert_eq!(seller_after_balance, seller_before_balance + (unitPrice.into() * 6));
        assert_eq!(buyer3_after_balance, buyer3_before_balance - (unitPrice.into() * 3));

        let partialBidSignatures = load(
            openmark_address,
            map_entry_address(selector!("partialBidSignatures"), (*signed_bids.at(2)).signature),
            1,
        );
        assert_eq!((*partialBidSignatures.at(0)).try_into().unwrap(), 0_u128);
        let usedSignatures = load(
            openmark_address,
            map_entry_address(selector!("usedSignatures"), (*signed_bids.at(2)).signature),
            1,
        );
        assert_eq!(*usedSignatures.at(0), true.into());
    }
}

#[test]
#[available_gas(2000000)]
fn cancel_bid_works() {
    let erc721_address: ContractAddress = deploy_erc721_at(TEST_ERC721_ADDRESS.try_into().unwrap());

    let openmark_address = deploy_openmark();
    let buyer1: ContractAddress = TEST_BUYER1.try_into().unwrap();

    let bid = Bid { nftContract: erc721_address, amount: 1, unitPrice: 3, salt: 4, expiry: 5 };

    {
        start_cheat_caller_address(openmark_address, buyer1);

        let mut spy = spy_events(SpyOn::One(openmark_address));

        let OpenMarkDispatcher = IOpenMarkDispatcher { contract_address: openmark_address };
        let (sig1, _, _) = BID_SIGNATURES();

        OpenMarkDispatcher.cancel_bid(bid, sig1);

        let usedSignatures = load(
            openmark_address, map_entry_address(selector!("usedSignatures"), sig1,), 1,
        );

        assert_eq!(*usedSignatures.at(0), true.into());
        // events
        let expected_event = OpenMarkEvent::BidCancelled(BidCancelled { who: buyer1, bid, });
        spy.assert_emitted(@array![(openmark_address, expected_event)]);
    }
}

