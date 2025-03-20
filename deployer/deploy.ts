import { RpcProvider, Account, constants, CallData, RawArgs, json } from 'starknet';
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

async function do_deploy(name: string, classHash: string, constructorData: RawArgs): Promise<string> {
    const account0 = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    const { abi: contractAbi } = await provider.getClassByHash(classHash);
    if (contractAbi === undefined) {
        throw new Error('No ABI found.');
    }

    const contractCallData = new CallData(contractAbi);
    const contractConstructor = contractCallData.compile('constructor', constructorData);

    const deployResponse = await account0.deployContract({
        classHash,
        constructorCalldata: contractConstructor,
    });

    console.log(`✅ ${name}:`, deployResponse.address);
    return deployResponse.address;
}

async function deploy() {
    // Load class hashes
    const classHashes: ClassHashRecord = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));

    // Load existing deployed addresses or initialize an empty object
    let deployedAddresses: DeployedRecord = {};
    if (fs.existsSync('./deployed.json')) {
        deployedAddresses = json.parse(fs.readFileSync('./deployed.json', 'utf8'));
    }

    // Deploy OpenMark if missing
    if (!deployedAddresses['OpenMark'] || deployedAddresses['OpenMark'] === '') {
        const data: RawArgs = {
            owner: Deployer,
        };
        deployedAddresses['OpenMark'] = await do_deploy('OpenMark', classHashes['OpenMark'], data);
    } else {
        console.log(`Skipping OpenMark: already deployed at ${deployedAddresses['OpenMark']}`);
    }

    // Deploy Open Collection if missing (assuming OERC721)
    if (!deployedAddresses['OpenCollection'] || deployedAddresses['OpenCollection'] === '') {
        const data: RawArgs = {
            owner: Deployer,
            name: 'Open Collection',
            symbol: 'OC',
            baseURI: '',
            maxTokenId: 1000,
            royaltyPercentage: 500, // 5%
        };
        deployedAddresses['OpenCollection'] = await do_deploy('OpenCollection', classHashes['OERC721'], data);
    } else {
        console.log(`Skipping OpenCollection: already deployed at ${deployedAddresses['OpenCollection']}`);
    }

    // Deploy Open Launchpad if missing
    if (!deployedAddresses['OpenLaunchpad'] || deployedAddresses['OpenLaunchpad'] === '') {
        const commission = 300; // 3%
        const selector_classhash = classHashes['StageSelector'];
        const batch_selector_classhash = classHashes['StageBatchSelector'];

        const data: RawArgs = {
            owner: Deployer,
            commission,
            selector_classhash,
            batch_selector_classhash,
        };
        deployedAddresses['OpenLaunchpad'] = await do_deploy('OpenLaunchpad', classHashes['OpenLaunchpad'], data);
    } else {
        console.log(`Skipping OpenLaunchpad: already deployed at ${deployedAddresses['OpenLaunchpad']}`);
    }

    // Deploy OERC721Factory if missing
    if (!deployedAddresses['OERC721Factory'] || deployedAddresses['OERC721Factory'] === '') {
        const collection_classhash = classHashes['OERC721'];
        const data: RawArgs = {
            owner: Deployer,
            collection_classhash,
        };
        deployedAddresses['OERC721Factory'] = await do_deploy('OERC721Factory', classHashes['OERC721Factory'], data);
    } else {
        console.log(`Skipping OERC721Factory: already deployed at ${deployedAddresses['OERC721Factory']}`);
    }

    // Deploy OERC1155Factory if missing
    if (!deployedAddresses['OERC1155Factory'] || deployedAddresses['OERC1155Factory'] === '') {
        const collection_classhash = classHashes['OERC1155'];
        const data: RawArgs = {
            owner: Deployer,
            collection_classhash,
        };
        deployedAddresses['OERC1155Factory'] = await do_deploy('OERC1155Factory', classHashes['OERC1155Factory'], data);
    } else {
        console.log(`Skipping OERC1155Factory: already deployed at ${deployedAddresses['OERC1155Factory']}`);
    }

    // Deploy LaunchpadFactory if missing
    if (!deployedAddresses['LaunchpadFactory'] || deployedAddresses['LaunchpadFactory'] === '') {
        const launchpad_classhash = classHashes['Launchpad'];
        const commission = 0;
        const selector_classhash = classHashes['StageSelector'];
        const batch_selector_classhash = classHashes['StageBatchSelector'];

        const data: RawArgs = {
            owner: Deployer,
            launchpad_classhash,
            commission,
            selector_classhash,
            batch_selector_classhash,
        };
        deployedAddresses['LaunchpadFactory'] = await do_deploy('LaunchpadFactory', classHashes['LaunchpadFactory'], data);
    } else {
        console.log(`Skipping LaunchpadFactory: already deployed at ${deployedAddresses['LaunchpadFactory']}`);
    }

    // Save deployed addresses to file
    fs.writeFileSync('./deployed.json', JSON.stringify(deployedAddresses, null, 2));
    console.log('Deployed addresses saved to deployed.json');
}

deploy()
    .then(() => console.log('Deployment completed'))
    .catch(err => console.error('Error:', err));