
import { RpcProvider, byteArray, ByteArray, Account, constants, CallData, json, shortString, Calldata } from 'starknet';
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

async function callMintURIs() {
    const account = new Account(provider, OWNER, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    // Load deployed addresses
    const deployedAddresses: DeployedRecord = json.parse(fs.readFileSync('./deployed.json', 'utf8'));
    const OPEN_COLLECTION = deployedAddresses['OpenCollection'];

    if (!OPEN_COLLECTION || OPEN_COLLECTION === '') {
        throw new Error('OpenCollection address not found in deployed.json or is empty');
    }

    // Load the class hash from classhashes.json to get the ABI
    const classHashes: { [key: string]: string } = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    const openCollectionClassHash = classHashes['OpenCollection'];

    // Get the ABI from the class hash
    const { abi } = await provider.getClassByHash(openCollectionClassHash);
    if (!abi) {
        throw new Error(`No ABI found for class hash ${openCollectionClassHash}`);
    }

    const calldata = CallData.compile({
        to: OWNER,
        uris: [
            byteArray.byteArrayFromString('ipfs://QmXmChYqhfXhtrZafjkREFBKomdk4cy345bJTnvBepAqv3/0'),
        ]
    });

    // Execute the transaction
    const txResponse = await account.execute({
        contractAddress: OPEN_COLLECTION,
        entrypoint: 'mintURIs',
        calldata,
    });

    console.log(`Called mintURIs on OpenCollection at ${OPEN_COLLECTION}. Tx: ${txResponse.transaction_hash}`);
    await provider.waitForTransaction(txResponse.transaction_hash);
    console.log('Transaction confirmed');
}

callMintURIs()
    .then(() => console.log('Test call completed'))
    .catch(err => console.error('Error:', err));


