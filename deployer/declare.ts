// SPDX-License-Identifier: GPL-3.0
// OpenMark Contract Declaration Script
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

/// # OpenMark Contract Declaration Script
///
/// This script manages the declaration of OpenMark contracts on StarkNet:
/// - Declares all contract classes from their Sierra and CASM artifacts
/// - Checks if classes are already declared before proceeding
/// - Saves computed class hashes to classhashes.json
/// - Supports all OpenMark-related contracts including factories and implementations

import { RpcProvider, Account, constants, json, hash } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

const DELAY_MS = 10000;
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

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

    const computedClassHash = hash.computeContractClassHash(sierraArtifact);

    try {
        await provider.getClassByHash(computedClassHash);
        console.log(`${contractName} already declared with class hash: ${computedClassHash}`);
        return computedClassHash;
    } catch (error) {
        // Class not declared yet, proceed with declaration
    }

    const declareResponse = await account.declare({
        contract: sierraArtifact,
        casm: casmArtifact,
    }, {
        maxFee: '0x0',
        version: constants.TRANSACTION_VERSION.V3,
    });

    console.log(`✅ ${contractName} declared - Class hash: ${declareResponse.class_hash}`);
    return declareResponse.class_hash;
}

async function declareAll() {
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);
    const classHashes: ClassHashRecord = {};

    const contractArtifacts: { [key: string]: { sierra: string; casm: string } } = {
        'OpenMark': {
            sierra: './target/dev/openmark_OpenMark.contract_class.json',
            casm: './target/dev/openmark_OpenMark.compiled_contract_class.json',
        },
        'OpenCollection': {
            sierra: './target/dev/openmark_OpenCollection.contract_class.json',
            casm: './target/dev/openmark_OpenCollection.compiled_contract_class.json',
        },
        'OERC721Factory': {
            sierra: './target/dev/openmark_OERC721Factory.contract_class.json',
            casm: './target/dev/openmark_OERC721Factory.compiled_contract_class.json',
        },
        'OERC1155Factory': {
            sierra: './target/dev/openmark_OERC1155Factory.contract_class.json',
            casm: './target/dev/openmark_OERC1155Factory.compiled_contract_class.json',
        },
        'StageFactory': {
            sierra: './target/dev/openmark_StageFactory.contract_class.json',
            casm: './target/dev/openmark_StageFactory.compiled_contract_class.json',
        },
        'OERC721': {
            sierra: './target/dev/openmark_OERC721.contract_class.json',
            casm: './target/dev/openmark_OERC721.compiled_contract_class.json',
        },
        'OERC1155': {
            sierra: './target/dev/openmark_OERC1155.contract_class.json',
            casm: './target/dev/openmark_OERC1155.compiled_contract_class.json',
        },
        'StageSelector': {
            sierra: './target/dev/openmark_StageSelector.contract_class.json',
            casm: './target/dev/openmark_StageSelector.compiled_contract_class.json',
        },
        'StageBatchSelector': {
            sierra: './target/dev/openmark_StageBatchSelector.contract_class.json',
            casm: './target/dev/openmark_StageBatchSelector.compiled_contract_class.json',
        },
        'StageVRF': {
            sierra: './target/dev/openmark_StageVRF.contract_class.json',
            casm: './target/dev/openmark_StageVRF.compiled_contract_class.json',
        },
    };

    for (const [contractName, { sierra, casm }] of Object.entries(contractArtifacts)) {
        try {
            classHashes[contractName] = await declareContract(account, contractName, sierra, casm);
            await delay(DELAY_MS);
        } catch (error) {
            console.error(`Error declaring ${contractName}:`, error);
        }
    }

    fs.writeFileSync('./classhashes.json', JSON.stringify(classHashes, null, 2));
    console.log('Class hashes saved to classhashes.json');
}

declareAll()
    .then(() => console.log('Declaration completed successfully'))
    .catch(err => console.error('Error during declaration:', err));