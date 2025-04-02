import {
    RpcProvider, byteArray, ByteArray, Account, constants, CallData, json, CairoOption,
    CairoOptionVariant, Calldata, Contract, RawArgs, hash, CairoCustomEnum, cairo
} from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
import { do_deploy } from './common';
import Controller from "@cartridge/controller";

// Load environment variables from .env file (e.g., RPC URL, private key)
dotenv.config();

// Configuration constants
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const Deployer = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';

const STRK = '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d';
const ERC1155_COLLECTION = '0x1e6c3aafa77a9d555f9694444d1b188f1129ca440418660e995eb8d48fe5127';

const STAGE_VRF_ADDRESS = '';
const VRF_PROVIDER = '0x51fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f';

const ZERO = '0x0000000000000000000000000000000000000000';
const MINTER_ROLE = 'MINTER_ROLE';

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
    const deployed: { [key: string]: string } = json.parse(fs.readFileSync('./deployed.json', 'utf8'));
    const classHashes: { [key: string]: string } = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);
    // Initialize the controller
    const STAGE_FACTORY_ADDRESS = deployed["StageFactory"];

    // Step 1: Deploy ERC1155 tokens (or use an existing one for simplicity)
    let nftAddress: string = ERC1155_COLLECTION;
    if (nftAddress === "") {
        const data: RawArgs = {
            owner: Deployer,
            name: 'Test Ponies',
            symbol: 'OC',
            uri: 'ipfs://QmevyP9yyRSyYk3FkQaHK5bNj4kdSpWTDYnB2SrNhwnuje',
            maxTokenId: 1000,
            royaltyPercentage: 500, // 5%
        };
        nftAddress = await do_deploy('OERC1155', Deployer, privateKey0, classHashes['OERC1155'], data);
    }


    // Step 2: Create VRF Stage from Stage Factory
    let stageAddress: string = STAGE_VRF_ADDRESS;
    if (stageAddress === "") {
        const { abi: testAbi } = await provider.getClassAt(STAGE_FACTORY_ADDRESS);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        const stageFactoryContract = new Contract(testAbi, STAGE_FACTORY_ADDRESS, provider).typedv2(testAbi);
        stageFactoryContract.connect(account);

        const stage = {
            stageType: new CairoCustomEnum({ "Randomness": StageType.Randomness }),
            collection: nftAddress,
            payment: STRK,
            price: "100000000000000000", // 0.1 STRK in wei
            maxAllocation: 100,
            limit: 10,
            startTime: Math.floor(Date.now() / 1000), // Current timestamp
            endTime: Math.floor(Date.now() / 1000) + 86400, // 24 hour from now
        };

        const stageId = 10004; // Unique stage ID
        const createTx = await stageFactoryContract.createInstance(
            stageId,
            stage,
            new CairoOption(CairoOptionVariant.None), // No root whitelist
            [],   // No collection whitelists
        );

        const createReceipt = await provider.waitForTransaction(createTx.transaction_hash);
        if (createReceipt.isSuccess()) {
            console.log("StageVRF creation succeeded!");
            stageAddress = await stageFactoryContract.getInstance(stageId);
            stageAddress = '0x' + BigInt(stageAddress).toString(16);
            console.log(`StageVRF deployed at: ${stageAddress}`);
        }
    }

    // Grant role Minter role for stage
    {
        const { abi: erc1155Abi } = await provider.getClassAt(nftAddress);
        if (erc1155Abi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        const collectionContract = new Contract(erc1155Abi, nftAddress, provider).typedv2(erc1155Abi);
        collectionContract.connect(account);
        const approveTx = await collectionContract.grant_role(MINTER_ROLE, stageAddress);
        const approveReceipt = await provider.waitForTransaction(approveTx.transaction_hash);
        if (approveReceipt.isSuccess()) {
            console.log("Grant Minter Role Succeeded!");
        }
    }

    // Step 3: Setup Drop Table
    if (stageAddress !== '') {
        const { abi: testAbi } = await provider.getClassAt(stageAddress);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        const stageContract = new Contract(testAbi, stageAddress, provider).typedv2(testAbi);
        stageContract.connect(account);

        const dropTable = [
            { token_id: 0, weight: 50 },
            { token_id: 1, weight: 30 },
            { token_id: 2, weight: 20 },
            { token_id: 3, weight: 10 },
            { token_id: 4, weight: 10 },
            { token_id: 5, weight: 10 },
            { token_id: 6, weight: 5 },
        ];
        const setupTx = await stageContract.setup(dropTable);
        const setupReceipt = await provider.waitForTransaction(setupTx.transaction_hash);
        if (setupReceipt.isSuccess()) {
            console.log("Drop table setup succeeded!");
        }
    }
}

// Execute the test and handle its promise
testVrfStageBuy()
    .then(() => console.log('VRF Stage Buy Test completed'))
    .catch(err => console.error('Error:', err));