pub mod LPErrors {
    pub const STAGE_NOT_FOUND: felt252 = 'Launchpad: stage not found';
    pub const STAGE_NOT_STARTED: felt252 = 'Launchpad: stage not started';
    pub const STAGE_ENDED: felt252 = 'Launchpad: stage has ended';
    pub const EXCEED_LIMIT: felt252 = 'Launchpad: exceed limit';
    pub const SOLD_OUT: felt252 = 'Launchpad: sold out';
    pub const WHITELIST_FAILED: felt252 = 'Launchpad: whitelist failed';
    pub const INVALID_PAYMENT_TOKEN: felt252 = 'Launchpad: invalid payment';
    pub const LENGTH_MISMATCH: felt252 = 'Launchpad: length mismatch';
    pub const ZERO_MINT_AMOUNT: felt252 = 'Launchpad: zero mint amount';
    pub const LAUNCHPAD_CLOSED: felt252 = 'Launchpad: closed';
    pub const NO_SALES: felt252 = 'Launchpad: no sales';
    pub const INVALID_PAY_VALUE: felt252 = 'Launchpad: invalid pay value';
    pub const WITHDRAW_FAILED: felt252 = 'Launchpad: withdraw failed';

    pub const UNAUTHORIZED_OWNER: felt252 = 'Launchpad: unauthorized owner';
    pub const MISSING_MINTER_ROLE: felt252 = 'Launchpad: missing minter role';
    pub const NOT_STAGE_OWNER: felt252 = 'Launchpad: not stage owner';
    pub const STAGE_ID_USED: felt252 = 'Launchpad: stage id used';

    pub const INVALID_DURATION: felt252 = 'Launchpad: invalid duration';
    pub const SALE_DURATION_EXCEEDED: felt252 = 'Launchpad: duration exceeded';
}
