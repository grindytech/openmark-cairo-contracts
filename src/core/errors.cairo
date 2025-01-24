pub mod OMErrors {
    /// Signature already used.
    pub const SIGNATURE_USED: felt252 = 'OM: sig used';

    /// Invalid signature
    pub const INVALID_SIGNATURE: felt252 = 'OM: invalid sig';

    /// Invalid signature length (2)
    pub const INVALID_SIGNATURE_LEN: felt252 = 'OM: invalid sig len';

    pub const ORDER_EXPIRED: felt252 = 'OM: order expired';

    /// Seller is not the owner of nft.
    pub const NOT_NFT_OWNER: felt252 = 'OM: not nft owner';

    pub const INSUFFICIENT_BALANCE: felt252 = 'OM: insufficient balance';

    pub const ZERO_ADDRESS: felt252 = 'OM: address is zero';

    /// Not allow trade with zero price
    pub const PRICE_IS_ZERO: felt252 = 'OM: price is zero';

    /// Invalid order type.
    pub const INVALID_ORDER_TYPE: felt252 = 'OM: invalid order type';

    pub const ZERO_NFTS: felt252 = 'OM: zero nfts';

    /// NFT does not match the NFT in a trade
    pub const NFT_MISMATCH: felt252 = 'OM: nft mismatch';

    /// Payment token does not match the payment in a trade
    pub const PAYMENT_MISMATCH: felt252 = 'OM: payment mismatch';

    /// Commission exceeds maximum allowed.
    pub const INVALID_COMMISSION: felt252 = 'OM: invalid commission';

    /// Payment token not allowd
    pub const INVALID_PAYMENT_TOKEN: felt252 = 'OM: Invalid payment token';

    /// Exceeds Available Amount
    pub const EXCEEDS_AVAILABLE_AMOUNT: felt252 = 'OM: Exceed available amount';
}