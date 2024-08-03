/// Signature already used.
pub const SIGNATURE_USED: felt252 = 'OPENMARK: sig used';

/// Invalid signature
pub const INVALID_SIGNATURE: felt252 = 'OPENMARK: invalid sig';

/// Invalid signature length (2)
pub const INVALID_SIGNATURE_LEN: felt252 = 'OPENMARK: invalid sig len';

pub const ORDER_EXPIRED: felt252 = 'OPENMARK: order expired';

pub const BID_EXPIRED: felt252 = 'OPENMARK: bid expired';

/// Seller is not the owner of nft.
pub const NOT_NFT_OWNER: felt252 = 'OPENMARK: not nft owner';

pub const INSUFFICIENT_BALANCE: felt252 = 'OPENMARK: insufficient balance';

pub const ZERO_ADDRESS: felt252 = 'OPENMARK: address is zero';

/// Not allow trade with zero price
pub const PRICE_IS_ZERO: felt252 = 'OPENMARK: price is zero';

/// Invalid order type.
pub const INVALID_ORDER_TYPE: felt252 = 'OPENMARK: invalid order type';

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

/// Commission exceeds maximum allowed.
pub const COMMISSION_TOO_HIGH: felt252 = 'OPENMARK: commission too high';

/// Payment token not allowd
pub const INVALID_PAYMENT_TOKEN: felt252 = 'OPENMARK: Invalid payment token';

