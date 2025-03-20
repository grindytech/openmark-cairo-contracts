pub mod LPErrors {
    pub const STAGE_NOT_FOUND: felt252 = 'OM: stage not found';
    pub const STAGE_NOT_STARTED: felt252 = 'OM: stage not started';
    pub const STAGE_ENDED: felt252 = 'OM: stage has ended';
    pub const EXCEED_LIMIT: felt252 = 'OM: exceed limit';
    pub const SOLD_OUT: felt252 = 'OM: sold out';
    pub const ROOT_WHITELIST_FAILED: felt252 = 'OM: root whitelist failed';
    pub const COLLECTION_WHITELIST_FAILED: felt252 = 'OM: collection whitelist failed';

    pub const LENGTH_MISMATCH: felt252 = 'OM: length mismatch';
    pub const ZERO_MINT_AMOUNT: felt252 = 'OM: zero mint amount';
    pub const STAGE_CLOSED: felt252 = 'OM: closed';
    pub const NO_SALES: felt252 = 'OM: no sales';
    pub const INVALID_PAY_VALUE: felt252 = 'OM: invalid pay value';
    pub const WITHDRAW_FAILED: felt252 = 'OM: withdraw failed';

    pub const UNAUTHORIZED_OWNER: felt252 = 'OM: unauthorized owner';
    pub const MISSING_MINTER_ROLE: felt252 = 'OM: missing minter role';
    pub const NOT_STAGE_OWNER: felt252 = 'OM: not stage owner';
    pub const STAGE_ID_USED: felt252 = 'OM: stage id used';

    pub const INVALID_DURATION: felt252 = 'OM: invalid duration';
}
