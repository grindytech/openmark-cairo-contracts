/// Signature already used.
pub const SIGNATURE_USED: felt252 = 'OPENMARK: sig used';

/// Invalid signature
pub const INVALID_SIGNATURE: felt252 = 'OPENMARK: invalid sig';

/// Invalid signature length (2)
pub const INVALID_SIGNATURE_LEN: felt252 = 'OPENMARK: invalid sig len';

// Signature is expired.
pub const SIGNATURE_EXPIRED: felt252 = 'OPENMARK: sig expired';

/// Seller is not the owner of nft.
pub const SELLER_NOT_OWNER: felt252 = 'OPENMARK: seller not owner';

pub const ZERO_ADDRESS: felt252 = 'OPENMARK: address is zero';

/// Not allow trade with zero price
pub const PRICE_IS_ZERO: felt252 = 'OPENMARK: price is zero';

/// Invalid order type.
pub const INVALID_ORDER_TYPE: felt252 = 'OPENMARK: invalid order type';

/// Exceeds number of bids allowd in 'fillBids'.
pub const TOO_MANY_BIDS: felt252 = 'OPENMARK: too many bids';

/// Exceeds number of nfts allowd in 'fillBids'.
pub const TOO_MANY_NFTS: felt252 = 'OPENMARK: too many nfts';

/// There is no bid in 'fill_bids'.
pub const NO_BIDS: felt252 = 'OPENMARK: no bids';

/// Bid with zero amount nft
pub const ZERO_BIDS_AMOUNT: felt252 = 'OPENMARK: zero bids amount';

// Asking price higher than bid price.
pub const ASKING_PRICE_TOO_HIGH: felt252 = 'OPENMARK: asking too high';

/// NFT does not match the NFT in a trade
pub const NFT_MISMATCH: felt252 = 'OPENMARK: nft mismatch';

/// Payment token does not match the payment in a trade
pub const PAYMENT_MISMATCH: felt252 = 'OPENMARK: payment mismatch';

/// Number of NFTs provided exceeds number of NFTs in the bid.
pub const EXCEED_BID_NFTS: felt252 = 'OPENMARK: exceed bid nfts';

/// Number of NFTs provided is less than the minimum required by the bid.
pub const NOT_ENOUGH_BID_NFTS: felt252 = 'OPENMARK: not enough nfts';

/// Commission exceeds maximum allowed.
pub const COMMISSION_TOO_HIGH: felt252 = 'OPENMARK: commission too high';

/// Invalid construct with no payment token
pub const EMPTY_PAYMENT_TOKEN: felt252 = 'OPENMARK: empty payment token';

/// Payment token not allowd
pub const INVALID_PAYMENT_TOKEN: felt252 = 'OPENMARK: Invalid payment token';

/// Payment transfer failed
pub const PAYMENT_TRANSFER_FAILED: felt252 = 'OPENMARK: Payment failed';

/// NFT transfer failed
pub const NFT_TRANSFER_FAILED: felt252 = 'OPENMARK: NFT transfer failed';
