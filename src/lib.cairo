mod primitives;
mod interface;
mod openmark;
mod openmark_nft;
mod openmark_coin;
mod hasher;
mod events;

mod mocks {
    mod hasher_mock;
}

#[cfg(test)]
mod tests {
    mod test_hasher;
    mod test_openmark;
}
