# API Documentation

## Overview

This document provides an overview of the public functions available in our smart contract. Each function's purpose, arguments, and emitted events are described to facilitate integration and usage.

## 1. `buy`

### Description
The `buy` function allows a buyer to purchase an NFT from a seller by verifying the provided signature, validating the order, executing the trade, updating the storage, and emitting relevant events.

### Arguments
- `seller: ContractAddress` - Address of the seller.
- `order: Order` - Order details containing information about the NFT.
- `signature: Span<felt252>` - Signature to verify the order.

### Events
- `OrderFilled { seller: ContractAddress, buyer: ContractAddress, order: Order }` - Emitted when an order is successfully filled.

## 2. `acceptOffer`

### Description
The `acceptOffer` function allows a seller to accept an offer from a buyer. It verifies the provided signature, validates the order, executes the trade, updates the storage, and emits relevant events.

### Arguments
- `buyer: ContractAddress` - Address of the buyer.
- `order: Order` - Order details containing information about the NFT.
- `signature: Span<felt252>` - Signature to verify the order.

### Events
- `OrderFilled { seller: ContractAddress, buyer: ContractAddress, order: Order }` - Emitted when an order is successfully filled.

## 3. `fillBids`

### Description
The `fillBids` function allows the contract to process multiple bids for NFTs in a single transaction. It verifies the provided signatures, validates the bids, calculates commissions, executes the trades, updates the storage, and emits relevant events for each bid filled.

### Arguments
- `bids: Span<SignedBid>` - Span of signed bids to be processed.
- `nftContract: ContractAddress` - Address of the NFT contract.
- `tokenIds: Span<u128>` - Span of token IDs to be traded.
- `paymentToken: ContractAddress` - Address of the payment token
- `askingPrice: u128` - Asking price for the NFTs.

### Events
- `BidFilled { seller: ContractAddress, bidder: ContractAddress, bid: Bid, tokenIds: Span<u128> }` - Emitted for each bid that is successfully filled.

## 4. `cancelOrder`

### Description
The `cancelOrder` function allows a user to cancel an order by verifying the provided signature and updating the storage. It emits a relevant event upon successful cancellation.

### Arguments
- `order: Order` - Order details to be cancelled.
- `signature: Span<felt252>` - Signature to verify the cancellation request.

### Events
- `OrderCancelled { who: ContractAddress, order: Order }` - Emitted when an order is successfully cancelled.

## 5. `cancelBid`

### Description
The `cancelBid` function allows a user to cancel a bid by verifying the provided signature and updating the storage. It emits a relevant event upon successful cancellation.

### Arguments
- `bid: Bid` - Bid details to be cancelled.
- `signature: Span<felt252>` - Signature to verify the cancellation request.

### Events
- `BidCancelled { who: ContractAddress, bid: Bid }` - Emitted when a bid is successfully cancelled.

## Usage Notes
- Ensure that signatures are valid and conform to the expected format.
- Orders and bids must meet the contract's requirements for validation and execution.
- Proper handling of emitted events is crucial for maintaining the integrity of off-chain applications interacting with this contract.
