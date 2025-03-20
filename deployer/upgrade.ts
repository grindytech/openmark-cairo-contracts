import { RpcProvider, Account, constants, json, hash, CallData } from 'starknet';
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

interface DeployedRecord {
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
        return computedClassHash; // Return existing class hash if already declared
    } catch (error) {
        `Failed to check class hash for ${contractName}: ${(error as Error).message}`
    }

    // If not declared, declare the contract
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

async function upgradeContract(
    account: Account,
    contractName: string,
    contractAddress: string,
    newClassHash: string
) {
    const { abi } = await provider.getClassByHash(newClassHash);
    if (!abi) {
        throw new Error(`No ABI found for class hash ${newClassHash}`);
    }

    const callData = new CallData(abi);
    const calldata = callData.compile('upgrade', {
        new_class_hash: newClassHash,
    });

    const txResponse = await account.execute({
        contractAddress,
        entrypoint: 'upgrade',
        calldata,
    });

    console.log(`Upgraded ${contractName} at ${contractAddress} to classHash ${newClassHash}. Tx: ${txResponse.transaction_hash}`);
    await provider.waitForTransaction(txResponse.transaction_hash);
}

async function upgrade() {
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    // Load existing class hashes and deployed addresses
    const classHashes: ClassHashRecord = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    const deployedAddresses: DeployedRecord = json.parse(fs.readFileSync('./deployed.json', 'utf8'));

    // Contracts to check for upgrades
    const contractsToUpgrade = [
        'OpenMark',
        'OpenLaunchpad',
        'OERC721Factory',
        'OERC1155Factory',
        'LaunchpadFactory',
    ];

    // Map of contract names to their artifact paths
    const contractArtifacts: { [key: string]: { sierra: string; casm: string } } = {
        'OpenMark': {
            sierra: './target/dev/openmark_OpenMark.contract_class.json',
            casm: './target/dev/openmark_OpenMark.compiled_contract_class.json',
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
    };

    // Check and upgrade each contract
    for (const contractName of contractsToUpgrade) {
        const currentClassHash = classHashes[contractName];
        const { sierra, casm } = contractArtifacts[contractName];
        const sierraArtifact = json.parse(fs.readFileSync(sierra, 'utf8'));
        const newComputedClassHash = hash.computeContractClassHash(sierraArtifact);

        if (currentClassHash !== newComputedClassHash) {
            console.log(`${contractName} has new code. Declaring new class hash...`);
            const newClassHash = await declareContract(account, contractName, sierra, casm);
            classHashes[contractName] = newClassHash;

            // Upgrade the contract if deployed
            const contractAddress = deployedAddresses[contractName];
            if (contractAddress && contractAddress !== '') {
                await upgradeContract(account, contractName, contractAddress, newClassHash);
            } else {
                console.log(`${contractName} not deployed yet, skipping upgrade.`);
            }
        } else {
            console.log(`${contractName} class hash unchanged: ${currentClassHash}`);
        }
    }

    // Save updated class hashes
    fs.writeFileSync('./classhashes.json', JSON.stringify(classHashes, null, 2));
    console.log('Updated class hashes saved to classhashes.json');
}

upgrade()
    .then(() => console.log('Upgrade completed'))
    .catch(err => console.error('Error:', err));