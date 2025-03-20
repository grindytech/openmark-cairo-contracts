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

async function declareAll() {
    const account0 = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);
    const classHashes: ClassHashRecord = {};

    // Declare OpenMark
    classHashes['OpenMark'] = await declareContract(
        account0,
        'OpenMark',
        './target/dev/openmark_OpenMark.contract_class.json',
        './target/dev/openmark_OpenMark.compiled_contract_class.json'
    );

    // Declare OpenCollection
    classHashes['OpenCollection'] = await declareContract(
        account0,
        'OpenCollection',
        './target/dev/openmark_OpenCollection.contract_class.json',
        './target/dev/openmark_OpenCollection.compiled_contract_class.json'
    );

    // Declare OpenLaunchpad
    classHashes['OpenLaunchpad'] = await declareContract(
        account0,
        'OpenLaunchpad',
        './target/dev/openmark_OpenLaunchpad.contract_class.json',
        './target/dev/openmark_OpenLaunchpad.compiled_contract_class.json'
    );

    // Declare OERC721Factory
    classHashes['OERC721Factory'] = await declareContract(
        account0,
        'OERC721Factory',
        './target/dev/openmark_OERC721Factory.contract_class.json',
        './target/dev/openmark_OERC721Factory.compiled_contract_class.json'
    );

    // Declare OERC1155Factory
    classHashes['OERC1155Factory'] = await declareContract(
        account0,
        'OERC1155Factory',
        './target/dev/openmark_OERC1155Factory.contract_class.json',
        './target/dev/openmark_OERC1155Factory.compiled_contract_class.json'
    );

    // Declare LaunchpadFactory
    classHashes['LaunchpadFactory'] = await declareContract(
        account0,
        'LaunchpadFactory',
        './target/dev/openmark_LaunchpadFactory.contract_class.json',
        './target/dev/openmark_LaunchpadFactory.compiled_contract_class.json'
    );
    
    //**  Declare Utilities *//
    
    // Declare OERC721
    classHashes['OERC721'] = await declareContract(
        account0,
        'OERC721',
        './target/dev/openmark_OERC721.contract_class.json',
        './target/dev/openmark_OERC721.compiled_contract_class.json'
    );

    // Declare OERC1155
    classHashes['OERC1155'] = await declareContract(
        account0,
        'OERC1155',
        './target/dev/openmark_OERC1155.contract_class.json',
        './target/dev/openmark_OERC1155.compiled_contract_class.json'
    );
   
    // Declare Launchpad
    classHashes['Launchpad'] = await declareContract(
        account0,
        'Launchpad',
        './target/dev/openmark_Launchpad.contract_class.json',
        './target/dev/openmark_Launchpad.compiled_contract_class.json'
    );
   
    // Declare StageSelector
    classHashes['StageSelector'] = await declareContract(
        account0,
        'StageSelector',
        './target/dev/openmark_StageSelector.contract_class.json',
        './target/dev/openmark_StageSelector.compiled_contract_class.json'
    );

    // Declare StageBatchSelector
    classHashes['StageBatchSelector'] = await declareContract(
        account0,
        'StageBatchSelector',
        './target/dev/openmark_StageBatchSelector.contract_class.json',
        './target/dev/openmark_StageBatchSelector.compiled_contract_class.json'
    );

    // Save class hashes to file
    fs.writeFileSync('./classhashes.json', JSON.stringify(classHashes, null, 2));
    console.log('Class hashes saved to classhashes.json');
}

declareAll()
    .then(() => console.log('Declaration completed'))
    .catch(err => console.error('Error:', err));