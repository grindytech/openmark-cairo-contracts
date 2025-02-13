pub mod OMErrors {
    /// Signature already used.
    pub const SIGNATURE_USED: felt252 = 'OM: sig used';

    /// Invalid signature
    pub const INVALID_SIGNATURE: felt252 = 'OM: invalid sig';

    /// Invalid signature length (2)
    pub const INVALID_SIGNATURE_LEN: felt252 = 'OM: invalid sig len';

    pub const ORDER_EXPIRED: felt252 = 'OM: order expired';

    pub const ZERO_ADDRESS: felt252 = 'OM: address is zero';

    /// Invalid order type.
    pub const INVALID_ORDER_TYPE: felt252 = 'OM: invalid order type';

    /// Commission exceeds maximum allowed.
    pub const INVALID_COMMISSION: felt252 = 'OM: invalid commission';

    /// Payment token not allowd
    pub const INVALID_PAYMENT_TOKEN: felt252 = 'OM: Invalid payment token';

    /// Exceeds Available Amount
    pub const EXCEEDS_AVAILABLE_AMOUNT: felt252 = 'OM: Exceed available amount';
}