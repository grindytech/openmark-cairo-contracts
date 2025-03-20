import { RpcProvider, Account, constants, json, hash } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

// Configuration
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const Deployer = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';

interface ClassHashRecord {
    [contractName: string]: string;
}

async function declareContract(
    account: Account,
    contractName: string,
    sierraPath: string,
    casmPath: string
): Promise<string> {
    let sierraArtifact: any, casmArtifact: any;
    try {
        sierraArtifact = json.parse(fs.readFileSync(sierraPath, 'utf8'));
        casmArtifact = json.parse(fs.readFileSync(casmPath, 'utf8'));
    } catch (error) {
        throw new Error(`Failed to load artifacts for ${contractName}: ${(error as Error).message}`);
    }

    if (!sierraArtifact || !sierraArtifact.sierra_program) {
        throw new Error(`Invalid Sierra artifact for ${contractName}: 'sierra_program' field missing`);
    }
    if (!casmArtifact) {
        throw new Error(`Invalid CASM artifact for ${contractName}: CASM file missing`);
    }

    // Compute the class hash from the Sierra artifact
    const computedClassHash = hash.computeContractClassHash(sierraArtifact);

    // Check if the class is already declared
    try {
        await provider.getClassByHash(computedClassHash);
        console.log(`${contractName} already declared with classHash:`, computedClassHash);
        return computedClassHash;
    } catch (error) {
        `Failed to check class hash for ${contractName}: ${(error as Error).message}`;
    }

    // Declare the contract
    const declareResponse = await account.declare({
        contract: sierraArtifact,
        casm: casmArtifact,
    }, {
        maxFee: '0x0',
        version: constants.TRANSACTION_VERSION.V3,
    });

    console.log(`${contractName} declared with classHash:`, declareResponse.class_hash);
    return declareResponse.class_hash;
}

async function declareAll() {
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);
    const classHashes: ClassHashRecord = {};

    // Map of contract names to their artifact paths
    const contractArtifacts: { [key: string]: { sierra: string; casm: string } } = {
        'OpenMark': {
            sierra: './target/dev/openmark_OpenMark.contract_class.json',
            casm: './target/dev/openmark_OpenMark.compiled_contract_class.json',
        },
        'OpenCollection': {
            sierra: './target/dev/openmark_OpenCollection.contract_class.json',
            casm: './target/dev/openmark_OpenCollection.compiled_contract_class.json',
        },
        'OpenLaunchpad': {
            sierra: './target/dev/openmark_OpenLaunchpad.contract_class.json',
            casm: './target/dev/openmark_OpenLaunchpad.compiled_contract_class.json',
        },
        'OERC721Factory': {
            sierra: './target/dev/openmark_OERC721Factory.contract_class.json',
            casm: './target/dev/openmark_OERC721Factory.compiled_contract_class.json',
        },
        'OERC1155Factory': {
            sierra: './target/dev/openmark_OERC1155Factory.contract_class.json',
            casm: './target/dev/openmark_OERC1155Factory.compiled_contract_class.json',
        },
        'LaunchpadFactory': {
            sierra: './target/dev/openmark_LaunchpadFactory.contract_class.json',
            casm: './target/dev/openmark_LaunchpadFactory.compiled_contract_class.json',
        },
        'OERC721': {
            sierra: './target/dev/openmark_OERC721.contract_class.json',
            casm: './target/dev/openmark_OERC721.compiled_contract_class.json',
        },
        'OERC1155': {
            sierra: './target/dev/openmark_OERC1155.contract_class.json',
            casm: './target/dev/openmark_OERC1155.compiled_contract_class.json',
        },
        'Launchpad': {
            sierra: './target/dev/openmark_Launchpad.contract_class.json',
            casm: './target/dev/openmark_Launchpad.compiled_contract_class.json',
        },
        'StageSelector': {
            sierra: './target/dev/openmark_StageSelector.contract_class.json',
            casm: './target/dev/openmark_StageSelector.compiled_contract_class.json',
        },
        'StageBatchSelector': {
            sierra: './target/dev/openmark_StageBatchSelector.contract_class.json',
            casm: './target/dev/openmark_StageBatchSelector.compiled_contract_class.json',
        },
    };

    // Declare all contracts
    for (const [contractName, { sierra, casm }] of Object.entries(contractArtifacts)) {
        classHashes[contractName] = await declareContract(account, contractName, sierra, casm);
    }

    // Save class hashes to file
    fs.writeFileSync('./classhashes.json', JSON.stringify(classHashes, null, 2));
    console.log('Class hashes saved to classhashes.json');
}

declareAll()
    .then(() => console.log('Declaration completed'))
    .catch(err => console.error('Error:', err));