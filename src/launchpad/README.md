# Launchpad Module

This module managing NFT minting stages, whitelists, and sales in a Starknet-based environment. The module facilitates stage updates, whitelist management, token purchases, and sales withdrawal, along with querying minting and whitelist information.

## Interfaces

### ILaunchpad

This interface handles the core functionalities for managing the launchpad:

- **`updateStages(stages: Span<Stage>, merkleRoots: Span<felt252>)`**  
  Updates the minting stages and associated Merkle roots.

- **`removeStages(stageIds: Span<u128>)`**  
  Removes stages by their IDs.

- **`updateWhitelist(stageIds: Span<u128>, merkleRoots: Span<felt252>)`**  
  Updates the whitelist for specific stages using Merkle roots.

- **`removeWhitelist(stageIds: Span<u128>)`**  
  Removes whitelist entries for specific stages by stage IDs.

- **`buy(stageId: u128, amount: u32, merkleProof: Span<felt252>)`**  
  Allows users to purchase tokens during a specific stage by providing the stage ID, amount, and Merkle proof for whitelist validation.

- **`withdrawSales(tokens: Span<ContractAddress>)`**  
  Withdraws sales proceeds to the provided token contract addresses.

---

### ILaunchpadProvider

This interface provides utilities for querying the state of the launchpad:

- **`getStage(stageId: u128)`**  
  Retrieves information about a specific stage by its ID.

- **`getActiveStage(stageId: u128)`**  
  Retrieves the currently active stage by its ID.

- **`getWhitelist(stageId: u128)`**  
  Returns the Merkle root of the whitelist for a specific stage, or `None` if no whitelist is present.

- **`getMintedCount(stageId: u128)`**  
  Returns the total number of tokens minted during a specific stage.

- **`getUserMintedCount(minter: ContractAddress, stageId: u128)`**  
  Retrieves the number of tokens minted by a specific user during a specific stage.

- **`verifyWhitelist(merkleRoot: felt252, merkleProof: Span<felt252>, minter: ContractAddress)`**  
  Verifies a user's presence in the whitelist by checking the Merkle proof against the Merkle root.

---

## Dependencies

This module uses Merkle Trees for whitelist verification. You can find more information on Merkle Trees and how to generate proofs using the `@ericnordelo/strk-merkle-tree` package:

- [Merkle Tree Documentation](https://www.npmjs.com/package/@ericnordelo/strk-merkle-tree)

---

## License

This project is licensed under the MIT License.