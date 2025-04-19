import { RpcProvider, Account, constants, json, Contract } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

// Configuration
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const OWNER = process.env.OWNER_PUBLIC_KEY || '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';

interface DeployedRecord {
    [contractName: string]: string;
}

async function createOERC721Instance() {
    const account = new Account(provider, OWNER, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    // Load deployed addresses
    const deployedAddresses: DeployedRecord = json.parse(fs.readFileSync('./deployed.json', 'utf8'));
    const factoryAddress = deployedAddresses['OERC721Factory'];

    if (!factoryAddress || factoryAddress === '') {
        throw new Error('OERC721Factory not deployed. Please deploy it first.');
    }

    // Get the ABI of the factory
    const { abi } = await provider.getClassAt(factoryAddress);
    if (!abi) {
        throw new Error('No ABI found for OERC721Factory.');
    }

    // Create contract instance
    const factoryContract = new Contract(abi, factoryAddress, provider).typedv2(abi);
    factoryContract.connect(account);

    // Parameters for the new OERC721 instance
    const instanceParams = {
        id: '1', // Unique ID for the collection
        name: 'My NFT Collection',
        symbol: 'MNC',
        base_uri: 'https://api.example.com/nft/',
        max_token_id: '1000', // Maximum token ID
        royalty_percentage: '500', // 5% royalty (in basis points)
    };

    try {
        console.log('Creating new OERC721 instance...');
        const txResponse = await factoryContract.createInstance(
            instanceParams.id,
            instanceParams.name,
            instanceParams.symbol,
            instanceParams.base_uri,
            instanceParams.max_token_id,
            instanceParams.royalty_percentage
        );

        await provider.waitForTransaction(txResponse.transaction_hash);
        console.log(`✅ OERC721 instance created - Tx: ${txResponse.transaction_hash}`);

        // Optionally, get the instance address from the factory
        const instanceAddress = await factoryContract.getInstance(instanceParams.id);
        console.log(`New OERC721 instance address: ${instanceAddress}`);
    } catch (error) {
        console.error('Error creating OERC721 instance:', error);
    }
}

createOERC721Instance()
    .then(() => console.log('Instance creation completed successfully'))
    .catch(err => console.error('Error during instance creation:', err));