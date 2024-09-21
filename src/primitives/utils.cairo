use starknet::{ContractAddress};
use openzeppelin::utils::{try_selector_with_fallback,};
use openzeppelin::utils::selectors;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;
use openmark::primitives::selectors as openmark_selectors;

pub fn payment_transfer_from(
    target: ContractAddress, sender: ContractAddress, recipient: ContractAddress, amount: u256
) {
    let mut args = array![];
    args.append_serde(sender);
    args.append_serde(recipient);
    args.append_serde(amount);

    try_selector_with_fallback(
        target, selectors::transfer_from, selectors::transferFrom, args.span()
    )
        .unwrap_syscall();
}

pub fn nft_transfer_from(
    target: ContractAddress, sender: ContractAddress, receiver: ContractAddress, token_id: u256
) {
    let mut args = array![];
    args.append_serde(sender);
    args.append_serde(receiver);
    args.append_serde(token_id);

    try_selector_with_fallback(
        target, selectors::transfer_from, selectors::transferFrom, args.span()
    )
        .unwrap_syscall();
}

pub fn payment_transfer(target: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
    let mut args = array![];
    args.append_serde(recipient);
    args.append_serde(amount);

    call_contract_syscall(target, selectors::transfer, args.span()).unwrap_and_cast()
}

pub fn nft_owner_of(target: ContractAddress, token_id: u256) -> ContractAddress {
    let mut args = array![];
    args.append_serde(token_id);

    try_selector_with_fallback(target, selectors::owner_of, selectors::ownerOf, args.span())
        .unwrap_and_cast()
}

pub fn payment_balance_of(target: ContractAddress, account: ContractAddress) -> u256 {
    let mut args = array![];
    args.append_serde(account);

    try_selector_with_fallback(target, selectors::balance_of, selectors::balanceOf, args.span())
        .unwrap_and_cast()
}


pub fn access_has_role(target: ContractAddress, role: felt252, account: ContractAddress) -> bool {
    let mut args = array![];
    args.append_serde(role);
    args.append_serde(account);

    try_selector_with_fallback(target, selectors::has_role, selectors::hasRole, args.span())
        .unwrap_and_cast()
}

pub fn nft_safe_batch_mint(
    target: ContractAddress, to: ContractAddress, quantity: u256,
) -> Span<u256> {
    let mut args = array![];
    args.append_serde(to);
    args.append_serde(quantity);

    try_selector_with_fallback(
        target, openmark_selectors::safeBatchMint, openmark_selectors::safe_batch_mint, args.span()
    )
        .unwrap_and_cast()
}

pub fn verify_payment_token(target: ContractAddress, token: ContractAddress) -> bool {
    let mut args = array![];
    args.append_serde(token);

    call_contract_syscall(target, openmark_selectors::verifyPaymentToken, args.span())
        .unwrap_and_cast()
}

pub fn get_commission(target: ContractAddress) -> u32 {
    let mut args = array![];
    call_contract_syscall(target, openmark_selectors::getCommission, args.span())
        .unwrap_and_cast()
}
