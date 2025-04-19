// SPDX-License-Identifier: GPL-3.0
// OpenMark Contract Deployment Script
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

/// # OpenMark Contract Deployment Script
///
/// This script manages the deployment of OpenMark contracts on StarkNet:
/// - Deploys contracts using class hashes from classhashes.json if not already deployed
/// - Constructs contract instances with specified constructor arguments
/// - Saves deployed addresses to deployed.json
/// - Supports OpenMark, OpenCollection, OERC721Factory, OERC1155Factory, and StageFactory contracts

import { RpcProvider, Account, constants, CallData, RawArgs, json } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

// Configuration
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const OWNER = process.env.OWNER_PUBLIC_KEY || '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';

interface ClassHashRecord {
    [contractName: string]: string;
}

interface DeployedRecord {
    [contractName: string]: string;
}

export async function do_deploy(name: string, classHash: string, constructorData: RawArgs): Promise<string> {
    const account0 = new Account(provider, OWNER, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

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

    console.log(`✅ ${name} deployed at: ${deployResponse.address}`);
    return deployResponse.address;
}

async function deploy() {
    const classHashes: ClassHashRecord = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    let deployedAddresses: DeployedRecord = {};
    if (fs.existsSync('./deployed.json')) {
        deployedAddresses = json.parse(fs.readFileSync('./deployed.json', 'utf8'));
    }

    // Deploy OpenMark if missing
    if (!deployedAddresses['OpenMark'] || deployedAddresses['OpenMark'] === '') {
        const data: RawArgs = {
            owner: OWNER,
        };
        deployedAddresses['OpenMark'] = await do_deploy('OpenMark', classHashes['OpenMark'], data);
    } else {
        console.log(`OpenMark already deployed at: ${deployedAddresses['OpenMark']}`);
    }

    // Deploy OpenCollection if missing (assuming OERC721)
    if (!deployedAddresses['OpenCollection'] || deployedAddresses['OpenCollection'] === '') {
        const data: RawArgs = {
            owner: OWNER,
            name: 'Open Collection',
            symbol: 'OC',
            baseURI: '',
            maxTokenId: 1000,
            royaltyPercentage: 500, // 5%
        };
        deployedAddresses['OpenCollection'] = await do_deploy('OpenCollection', classHashes['OpenCollection'], data);
    } else {
        console.log(`OpenCollection already deployed at: ${deployedAddresses['OpenCollection']}`);
    }

    // Deploy OERC721Factory if missing
    if (!deployedAddresses['OERC721Factory'] || deployedAddresses['OERC721Factory'] === '') {
        const collection_classhash = classHashes['OERC721'];
        const data: RawArgs = {
            owner: OWNER,
            collection_classhash,
        };
        deployedAddresses['OERC721Factory'] = await do_deploy('OERC721Factory', classHashes['OERC721Factory'], data);
    } else {
        console.log(`OERC721Factory already deployed at: ${deployedAddresses['OERC721Factory']}`);
    }

    // Deploy OERC1155Factory if missing
    if (!deployedAddresses['OERC1155Factory'] || deployedAddresses['OERC1155Factory'] === '') {
        const collection_classhash = classHashes['OERC1155'];
        const data: RawArgs = {
            owner: OWNER,
            collection_classhash,
        };
        deployedAddresses['OERC1155Factory'] = await do_deploy('OERC1155Factory', classHashes['OERC1155Factory'], data);
    } else {
        console.log(`OERC1155Factory already deployed at: ${deployedAddresses['OERC1155Factory']}`);
    }

    // Deploy StageFactory if missing
    if (!deployedAddresses['StageFactory'] || deployedAddresses['StageFactory'] === '') {
        const commission = 0;
        const stage_selector = classHashes['StageSelector'];
        const stage_batch_selector = classHashes['StageBatchSelector'];
        const stage_randomness = classHashes['StageVRF'];
        const VRF_PROVIDER = "0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f";

        const data: RawArgs = {
            owner: OWNER,
            commission: commission,
            stage_selector: stage_selector,
            stage_batch_selector: stage_batch_selector,
            stage_randomness: stage_randomness,
            vrf_provider: VRF_PROVIDER
        };
        deployedAddresses['StageFactory'] = await do_deploy('StageFactory', classHashes['StageFactory'], data);
    } else {
        console.log(`StageFactory already deployed at: ${deployedAddresses['StageFactory']}`);
    }

    fs.writeFileSync('./deployed.json', JSON.stringify(deployedAddresses, null, 2));
    console.log('Deployed addresses saved to deployed.json');
}

deploy()
    .then(() => console.log('Deployment completed successfully'))
    .catch(err => console.error('Error during deployment:', err));