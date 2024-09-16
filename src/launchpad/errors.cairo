pub mod LPErrors {
    pub const STAGE_NOT_FOUND: felt252 = 'Launchpad: stage not found';
    pub const STAGE_NOT_STARTED: felt252 = 'Launchpad: stage not started';
    pub const STAGE_ENDED: felt252 = 'Launchpad: stage has ended';
    pub const EXCEED_LIMIT: felt252 = 'Launchpad: exceed limit';
    pub const SOLD_OUT: felt252 = 'Launchpad: sold out';
    pub const WHITELIST_FAILED: felt252 = 'Launchpad: whitelist failed';
    pub const INVALID_PAYMENT_TOKEN: felt252 = 'Launchpad: invalid payment';
    pub const LENGTH_MISMATCH: felt252 = 'Launchpad: length mismatch';
    pub const INVALID_MINT_AMOUNT: felt252 = 'Launchpad: invalid mint amount';
    pub const LAUNCHPAD_CLOSED: felt252 = 'Launchpad: closed';
    pub const NO_SALES: felt252 = 'Launchpad: no sales';
    pub const INVALID_PAY_VALUE: felt252 = 'Launchpad: invalid pay value';
    pub const WITHDRAW_FAILED: felt252 = 'Launchpad: withdraw failed';
}