import {
    RpcProvider, Account, constants, CallData, json, CairoCustomEnum, Contract
} from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

// Load environment variables from .env file
dotenv.config();

// Configuration constants
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const Deployer = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';
const VRF_PROVIDER_ADDRESS = '0x51fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f';


async function testVrfProvider() {
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    const { abi: vrfProviderAbi } = await provider.getClassAt(VRF_PROVIDER_ADDRESS);
    if (vrfProviderAbi === undefined) {
        throw new Error('No ABI found for the contract.');
    }
    const vrfProviderContract = new Contract(vrfProviderAbi, VRF_PROVIDER_ADDRESS, provider).typedv2(vrfProviderAbi);
    vrfProviderContract.connect(account);


    //   Request randomness
    let calls =
        [{
            contractAddress: VRF_PROVIDER_ADDRESS,
            entrypoint: 'request_random',
            calldata: CallData.compile({
                caller: Deployer,
                source: { type: 0, address: Deployer }, // Using Source::Nonce variant
                // source: new CairoCustomEnum({ Nonce: Deployer }),
            }),
        },
        {
            contractAddress: VRF_PROVIDER_ADDRESS,
            entrypoint: 'consume_random',
            calldata: CallData.compile({
                source: new CairoCustomEnum({ Nonce: Deployer }),
            }),
        },
        ]

    // Multicall: request_random + buy
    const multicallTx = await account.execute(calls);
    const multicallReceipt = await provider.waitForTransaction(multicallTx.transaction_hash);
    if (multicallReceipt.isSuccess()) {
        console.log("Request Random Succeeded!");
    }


    // // Step 2: Consume randomness
    // console.log("Consuming randomness...");
    // try {
    //     // Call consume_random as a multicall to ensure atomicity with request
    //     const consumeTx = await account.execute([
    //         {
    //             contractAddress: VRF_PROVIDER_ADDRESS,
    //             entrypoint: 'consume_random',
    //             calldata: CallData.compile({
    //                 source: new CairoCustomEnum({ Nonce: Deployer }),
    //             }),
    //         },
    //     ]);
    //     console.log(`Consume TX Hash: ${consumeTx.transaction_hash}`);

    //     const consumeReceipt = await provider.waitForTransaction(consumeTx.transaction_hash);
    //     console.log("Consume Receipt:", JSON.stringify(consumeReceipt, null, 2));

    //     if (consumeReceipt.isSuccess()) {
    //         console.log("Randomness consumption succeeded!");
    //         // Attempt to extract the random value from the call output (if returned)
    //         const randomValue = await vrfProviderContract.call('consume_random', CallData.compile({
    //             source: new CairoCustomEnum({ Nonce: Deployer }),
    //         }));
    //         console.log("Random Value:", randomValue.toString());
    //     } else {
    //         console.log("Randomness consumption failed:", consumeReceipt || "No revert reason");
    //     }
    // } catch (error) {
    //     console.error("Error during consume_random:", error.message);
    // }
}

// Execute the test and handle its promise
testVrfProvider()
    .then(() => console.log('VRF Provider Test completed'))
    .catch(err => console.error('Error:', err));