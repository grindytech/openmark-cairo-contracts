use starknet::{ContractAddress};
use openzeppelin::utils::{try_selector_with_fallback};
use openzeppelin::utils::selectors;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::SyscallResultTrait;
use openmark::primitives::selectors as openmark_selectors;

pub fn _payment_transfer_from(
    target: ContractAddress, sender: ContractAddress, receiver: ContractAddress, amount: u256
) {
    let mut args = array![];
    args.append_serde(sender);
    args.append_serde(receiver);
    args.append_serde(amount);

    try_selector_with_fallback(
        target, selectors::transfer_from, selectors::transferFrom, args.span()
    )
        .unwrap_syscall();
}

pub fn _nft_owner_of(target: ContractAddress, token_id: u256) -> ContractAddress {
    let mut args = array![];
    args.append_serde(token_id);

    try_selector_with_fallback(target, selectors::owner_of, selectors::ownerOf, args.span())
        .unwrap_and_cast()
}

pub fn _payment_balance_of(target: ContractAddress, account: ContractAddress) -> u256 {
    let mut args = array![];
    args.append_serde(account);

    try_selector_with_fallback(target, selectors::balance_of, selectors::balanceOf, args.span())
        .unwrap_and_cast()
}

pub fn _safe_batch_mint(
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