# OpenMarkNFT API Documentation

## Overview

The `OpenMarkNFT` contract is a Cairo implementation of an NFT contract with ERC721-like functionalities, including minting tokens with and without URIs, batch minting, and setting URIs.

## Functions

### 1. `safe_mint(to: ContractAddress)`

Mints a new token to the specified address.

#### Parameters
- `to` (ContractAddress): The address to receive the newly minted token.

#### Events
- `TokenMinted { caller: ContractAddress, to: ContractAddress, token_id: u256, uri: ByteArray }`: Emitted when a new token is minted.

#### Example
```rust
openMarkNFT.safe_mint(receiver_address);
```

---

### 2. `safe_mint_with_uri(to: ContractAddress, uri: ByteArray)`

Mints a new token with a specific URI to the specified address.

#### Parameters
- `to` (ContractAddress): The address to receive the newly minted token.
- `uri` (ByteArray): The URI to assign to the newly minted token.

#### Events
- `TokenMinted { caller: ContractAddress, to: ContractAddress, token_id: u256, uri: ByteArray }`: Emitted when a new token is minted with a URI.

#### Example
```rust
openMarkNFT.safe_mint_with_uri(receiver_address, uri);
```

---

### 3. `safe_batch_mint(to: ContractAddress, quantity: u256)`

Mints multiple tokens to the specified address.

#### Parameters
- `to` (ContractAddress): The address to receive the newly minted tokens.
- `quantity` (u256): The number of tokens to mint.

#### Events
- `TokenMinted { caller: ContractAddress, to: ContractAddress, token_id: u256, uri: ByteArray }`: Emitted for each token minted.

#### Example
```rust
openMarkNFT.safe_batch_mint(receiver_address, 5);
```

---

### 4. `safe_batch_mint_with_uris(to: ContractAddress, uris: Span<ByteArray>)`

Mints multiple tokens with specific URIs to the specified address.

#### Parameters
- `to` (ContractAddress): The address to receive the newly minted tokens.
- `uris` (Span<ByteArray>): An array of URIs to assign to the newly minted tokens.

#### Events
- `TokenMinted { caller: ContractAddress, to: ContractAddress, token_id: u256, uri: ByteArray }`: Emitted for each token minted.

#### Example
```rust
let uris = vec![uri1, uri2, uri3];
openMarkNFT.safe_batch_mint_with_uris(receiver_address, uris);
```

---

### 5. `set_token_uri(token_id: u256, uri: ByteArray)`

Sets the URI for a specific token.

#### Parameters
- `token_id` (u256): The ID of the token to set the URI for.
- `uri` (ByteArray): The URI to assign to the token.

#### Requirements
- The caller must be the owner of the token.

#### Events
- `TokenURIUpdated { who: ContractAddress, token_id: u256, uri: ByteArray }`: Emitted when the token URI is updated.

#### Example
```rust
openMarkNFT.set_token_uri(token_id, new_uri);
```

---

### 6. `get_token_uri(token_id: u256) -> ByteArray`

Returns the URI for a specific token. If a specific URI for `token_id` is not set, it will return `base_uri/'token_id'`.

#### Parameters
- `token_id` (u256): The ID of the token to query the URI for.

#### Returns
- `ByteArray`: The URI of the specified token.

#### Example
```rust
let uri = openMarkNFT.get_token_uri(token_id);
```

---

### 7. `set_base_uri(base_uri: ByteArray)`

Sets a new base URI for the token collection. Can only be called by the owner.

#### Parameters
- `base_uri` (ByteArray): The new base URI to set.

#### Example
```rust
openMarkNFT.set_base_uri(new_base_uri);
```

---

This documentation provides an overview of the `OpenMarkNFT` contract's API, including its functions, events, and deployment details. For more information, refer to the contract's source code.