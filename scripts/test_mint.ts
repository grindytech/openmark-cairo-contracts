import { RpcProvider, byteArray, ByteArray, Account, constants, CallData, json, shortString, Calldata, Contract } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

// Load environment variables from .env file (e.g., RPC URL, private key)
dotenv.config();

// Configuration constants
// RPC endpoint for StarkNet Sepolia testnet; falls back to a public BlastAPI endpoint if not set in .env
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
// Initialize the RPC provider to interact with the StarkNet network
const provider = new RpcProvider({ nodeUrl: RPC });
// Private key for the deployer account; should be set in .env for security, empty string as fallback
const privateKey0 = process.env.DEPLOY_ACCOUNT_PRIVATE_KEY || '';
// Address of the deployer account (public key corresponding to privateKey0)
const DEPLOYER = process.env.DEPLOY_ACCOUNT_ADRESS || '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';
// Address of the STRK token contract on StarkNet Sepolia (used for payments)
const STRK = '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d';

// Define an interface for tracking deployed contract addresses (not used here but kept for potential future use)
interface DeployedRecord {
    [contractName: string]: string;
}

/**
 * Asynchronously mints tokens by approving payment and calling the buy function on the StageSelector contract.
 * This function interacts with StarkNet contracts to perform a token purchase.
 */
async function callMint() {
    // Create an account instance for transaction signing and execution
    // Uses TRANSACTION_VERSION.V3 for compatibility with the latest StarkNet protocol
    const account = new Account(provider, DEPLOYER, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    // Address of the deployed StageSelector contract where the buy function will be called
    const STAGE_ADDRESS = "0x075bbc9f5211ba9ffb3c1924b2d605f4bbea613d0b56a452c98343d060ec9685";

    // Step 1: Approve the STRK token contract to spend tokens on behalf of the deployer
    {
        // Fetch the ABI of the STRK token contract to interact with it
        const { abi: testAbi } = await provider.getClassAt(STRK);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        // Create a contract instance for the STRK token, typed with its ABI for better method access
        let paymentContract = new Contract(testAbi, STRK, provider).typedv2(testAbi);
        // Connect the account to the contract for signing transactions
        paymentContract.connect(account);
        // Approve the StageSelector contract to spend 5 STRK tokens (in wei: 5 * 10^18)
        let approve_tx = await paymentContract.approve(STAGE_ADDRESS, "5000000000000000000");
        // Wait for the approval transaction to be confirmed on-chain
        const approveReceipt = await provider.waitForTransaction(approve_tx.transaction_hash);
        if (approveReceipt.isSuccess()) {
            console.log("Approve Payment Succeed!");
        }
    }

    // Step 2: Call the buy function on the StageSelector contract to mint tokens
    {
        // Fetch the ABI of the StageSelector contract to interact with its buy function
        const { abi: testAbi } = await provider.getClassAt(STAGE_ADDRESS);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        // Create a contract instance for the StageSelector contract, typed with its ABI
        let contract = new Contract(testAbi, STAGE_ADDRESS, provider).typedv2(testAbi);
        // Connect the account to the contract for signing the buy transaction
        contract.connect(account);

        // Call the buy function with token ID [10] and a dummy Merkle proof [1234]
        // Note: Replace [1234] with an actual Merkle proof if whitelist validation is required
        let approve_tx = await contract.buy([10], [1234]);
        // Wait for the buy transaction to be confirmed on-chain
        const approveReceipt = await provider.waitForTransaction(approve_tx.transaction_hash);
        if (approveReceipt.isSuccess()) {
            console.log("Buy Succeed!");
        }
    }
}

// Execute the callMint function and handle its promise
callMint()
    .then(() => console.log('Test call completed')) // Log success when the entire process finishes
    .catch(err => console.error('Error:', err));     // Log any errors that occur during execution