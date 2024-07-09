mod primitives;
mod interface;
mod openmark;
mod hasher;
mod events;
mod errors;

mod utils {
    mod openmark_nft;
    mod openmark_coin;
    mod openmark_factory;
}

mod mocks {
    mod hasher_mock;
}

#[cfg(test)]
mod tests {
    mod test_hasher_works;
    mod test_openmark_works;
    mod test_buy_fails;
    mod test_accept_offer_fails;
    mod test_fill_bids_fails;
    mod common;
}
