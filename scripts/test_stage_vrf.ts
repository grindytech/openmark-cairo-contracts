import { RpcProvider, byteArray, ByteArray, Account, constants, CallData, json, shortString, Calldata, Contract, RawArgs } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
import { do_deploy } from '../deployer/deploy';

// Load environment variables from .env file (e.g., RPC URL, private key)
dotenv.config();

// Configuration constants
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const Deployer = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';
const STRK = '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d';
const STAGE_FACTORY_ADDRESS = '0x270464463aadca9d6f2f928d74159cf76da9234a8b7cd91976c972b354ab7d';

export enum StageType {
    // Buying specific token IDs
   Selector,
   // Batch buying with specific IDs and quantities
   BatchSelector, 
    // Minting fungible tokens
   TokenMint,
   // Buying random token(s)
   Randomness, 
}

async function testVrfStageBuy() {
    const classHashes: { [key: string]: string } = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    // Step 1: Deploy ERC1155 tokens (or use an existing one for simplicity)
    let nftAddress: string;
    {
        const data: RawArgs = {
            owner: Deployer,
            name: 'Test Ponies',
            symbol: 'OC',
            uri: 'ipfs://QmevyP9yyRSyYk3FkQaHK5bNj4kdSpWTDYnB2SrNhwnuje',
            maxTokenId: 1000,
            royaltyPercentage: 500, // 5%
        };
        nftAddress = await do_deploy('OERC1155', classHashes['OERC1155'], data);
    }

    // Step 2: Create VRF Stage from Stage Factory
    let stageAddress: string;
    {
        const { abi: testAbi } = await provider.getClassAt(STAGE_FACTORY_ADDRESS);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        const stageFactoryContract = new Contract(testAbi, STAGE_FACTORY_ADDRESS, provider).typedv2(testAbi);
        stageFactoryContract.connect(account);

        const stage = {
            stageType: StageType.Randomness, // StageType::Randomness (enum value, adjust if different)
            collection: nftAddress,
            payment: STRK,
            price: "100000000000000000", // 0.1 STRK in wei
            maxAllocation: 100,
            limit: 10,
            startTime: Math.floor(Date.now() / 1000), // Current timestamp
            endTime: Math.floor(Date.now() / 1000) + 86400, // 24 hour from now
        };

        const stageId = 42; // Unique stage ID
        const createTx = await stageFactoryContract.createInstance(
            stageId,
            stage,
            null, // No root whitelist
            [],   // No collection whitelists
        );
        const createReceipt = await provider.waitForTransaction(createTx.transaction_hash);
        if (createReceipt.isSuccess()) {
            console.log("StageVRF creation succeeded!");
            stageAddress = await stageFactoryContract.getStage(stageId);
            console.log(`StageVRF deployed at: ${stageAddress}`);
        }
    }

    // // Step 3: Setup Drop Table
    // {
    //     const stageContract = new Contract(stageVrfAbi, stageAddress, provider).typedv2(stageVrfAbi);
    //     stageContract.connect(account);

    //     const dropTable = [
    //         { token_id: 1, weight: 50 },
    //         { token_id: 2, weight: 30 },
    //         { token_id: 3, weight: 20 },
    //     ];
    //     const setupTx = await stageContract.setup(dropTable);
    //     const setupReceipt = await provider.waitForTransaction(setupTx.transaction_hash);
    //     if (setupReceipt.isSuccess()) {
    //         console.log("Drop table setup succeeded!");
    //     }
    // }

    // // Step 4: Approve STRK and Call Buy with Random
    // {
    //     // Approve STRK
    //     const paymentContract = new Contract(erc1155Abi, STRK, provider).typedv2(erc1155Abi);
    //     paymentContract.connect(account);
    //     const approveTx = await paymentContract.approve(stageAddress, "5000000000000000000"); // 5 STRK
    //     const approveReceipt = await provider.waitForTransaction(approveTx.transaction_hash);
    //     if (approveReceipt.isSuccess()) {
    //         console.log("Approve Payment Succeeded!");
    //     }

    //     // Get VRF Provider address from StageVRF
    //     const stageContract = new Contract(stageVrfAbi, stageAddress, provider).typedv2(stageVrfAbi);
    //     const vrfProviderAddress = await stageContract.get_vrf_provider();
    //     const vrfProviderContract = new Contract(vrfProviderAbi, vrfProviderAddress, provider).typedv2(vrfProviderAbi);
    //     vrfProviderContract.connect(account);

    //     // Multicall: request_random + buy
    //     const multicallTx = await account.execute([
    //         {
    //             contractAddress: vrfProviderAddress,
    //             entrypoint: 'request_random',
    //             calldata: CallData.compile({
    //                 caller: stageAddress,
    //                 source: { Nonce: Deployer }, // Using Source::Nonce variant
    //             }),
    //         },
    //         {
    //             contractAddress: stageAddress,
    //             entrypoint: 'buy',
    //             calldata: CallData.compile({
    //                 amount: 3, // Buy 3 tokens
    //                 merkleProof: [], // No whitelist in this example
    //             }),
    //         },
    //     ]);
    //     const multicallReceipt = await provider.waitForTransaction(multicallTx.transaction_hash);
    //     if (multicallReceipt.isSuccess()) {
    //         console.log("Buy with Random Succeeded!");
    //     }
    // }
}

// Execute the test and handle its promise
testVrfStageBuy()
    .then(() => console.log('VRF Stage Buy Test completed'))
    .catch(err => console.error('Error:', err));