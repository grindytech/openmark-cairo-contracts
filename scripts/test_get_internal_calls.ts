import { RpcProvider, byteArray, ByteArray, Account, constants, CallData, json, shortString, Calldata, Contract, num, hash } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

// Load environment variables from .env file (e.g., RPC URL, private key)
dotenv.config();

// Configuration constants
// RPC endpoint for StarkNet Sepolia testnet; falls back to a public BlastAPI endpoint if not set in .env
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
// Initialize the RPC provider to interact with the StarkNet network
const provider = new RpcProvider({ nodeUrl: RPC });


// Address of the STRK token contract on StarkNet Sepolia (used for payments)
const txHash = '0x6ad75e507f4266d160bdafd2e59b1079d0f0add150886c1404381fe69bf961c';
// Step 2: Define the ERC1155 contract ABI (partial ABI for TransferBatch event)
const erc1155Abi = [
    {
        name: 'TransferBatch',
        type: 'event',
        keys: [], // No indexed parameters in Starknet events (unlike Ethereum)
        data: [
            { name: 'operator', type: 'felt' }, // Address
            { name: 'from', type: 'felt' },    // Address
            { name: 'to', type: 'felt' },      // Address
            { name: 'ids', type: 'felt*' },    // Array of token IDs
            { name: 'values', type: 'felt*' }, // Array of amounts
        ],
    },
];


// Step 4: Function to fetch and parse the event
async function getTransferBatchEvent() {
    try {
        const keyFilter = [[num.toHex(hash.starknetKeccak('TransferBatch')), '0x8']];

        // Fetch the transaction receipt
        const receipt = await provider.getEvents({
            address: "0x02d34b927a277a6c6dc7a3d5df7f468cb6be63db5a99eae822ad8cffb4bf22fc", // NFT Collection Address
            from_block: { block_number: 660976 - 1 },
            to_block: { block_number: 660976 + 1 },
            keys: keyFilter,
            chunk_size: 10,
        });
        if (!receipt.events || receipt.events.length === 0) {
            console.log('No events found in the transaction receipt.');
            return;
        }

        // Step 5: Create a contract instance to parse events (optional, if using ABI)
        const contractAddress = '0x02d34b927a277a6c6dc7a3d5df7f468cb6be63db5a99eae822ad8cffb4bf22fc'; // Replace with your contract address
        const contract = new Contract(erc1155Abi, contractAddress, provider);

        console.log('receipt:', receipt);
        // // Step 6: Parse events from the receipt
        // const parsedEvents = contract.parseEvents(receipt);
        // console.log('Parsed Events:', parsedEvents);

        // // Step 7: Find and process the TransferBatch event
        // parsedEvents.forEach((event) => {
        //     if (event.TransferBatch) {
        //         const { operator, from, to, ids, values } = event.TransferBatch;
        //         console.log('TransferBatch Event Found:');
        //         console.log('Operator:', operator); // Hex address
        //         console.log('From:', from);         // Hex address
        //         console.log('To:', to);             // Hex address
        //         console.log('Token IDs:', ids);     // Array of BigInt
        //         console.log('Values:', values);     // Array of BigInt
        //     }
        // });

    } catch (error) {
        console.error('Error fetching or parsing event:', error);
    }
}

// Execute the callMint function and handle its promise
getTransferBatchEvent()
    .then(() => console.log('Test call completed')) // Log success when the entire process finishes
    .catch(err => console.error('Error:', err));     // Log any errors that occur during execution