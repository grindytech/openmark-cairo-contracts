// SPDX-License-Identifier: GPL-3.0
// OpenMark Contracts Upgrade Script
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

/// # OpenMark Contract Upgrade Script
///
/// This script manages the upgrade process for OpenMark contracts on StarkNet:
/// - Compares deployed contract class hashes with expected hashes from classhashes.json
/// - Upgrades contracts to the expected class hashes if they differ
/// - Declares new class hashes if they aren't already on-chain
/// - Supports OpenMark, OERC721Factory, OERC1155Factory, and StageFactory contracts

import { RpcProvider, Account, constants, json, hash, CallData } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

// Configuration
const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY || '';
const Deployer = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';

interface ClassHashRecord { [contractName: string]: string; }
interface DeployedRecord { [contractName: string]: string; }

const contractArtifacts: { [key: string]: { sierra: string; casm: string } } = {
    'OpenMark': {
        sierra: './target/dev/openmark_OpenMark.contract_class.json',
        casm: './target/dev/openmark_OpenMark.compiled_contract_class.json',
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
};

async function declareContract(
    account: Account,
    contractName: string,
    sierraPath: string,
    casmPath: string
): Promise<string> {
    const sierraArtifact = json.parse(fs.readFileSync(sierraPath, 'utf8'));
    const casmArtifact = json.parse(fs.readFileSync(casmPath, 'utf8'));

    const computedClassHash = hash.computeContractClassHash(sierraArtifact);

    try {
        await provider.getClassByHash(computedClassHash);
        console.log(`Class hash ${computedClassHash} already declared for ${contractName}`);
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

    console.log(`Declared new class hash for ${contractName}: ${declareResponse.class_hash}`);
    return declareResponse.class_hash;
}

async function upgradeContract(
    account: Account,
    contractName: string,
    contractAddress: string,
    newClassHash: string
) {
    const { abi } = await provider.getClassByHash(newClassHash);
    const callData = new CallData(abi);
    const calldata = callData.compile('upgrade', { new_class_hash: newClassHash });

    const txResponse = await account.execute({
        contractAddress,
        entrypoint: 'upgrade',
        calldata,
    });

    console.log(`✅ ${contractName} upgraded - Tx: ${txResponse.transaction_hash}`);
    await provider.waitForTransaction(txResponse.transaction_hash);
}

async function performUpgrades() {
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);
    const classHashes: ClassHashRecord = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    const deployedAddresses: DeployedRecord = json.parse(fs.readFileSync('./deployed.json', 'utf8'));

    const contractsToUpgrade = ['OpenMark', 'OERC721Factory', 'OERC1155Factory', 'StageFactory'];

    for (const contractName of contractsToUpgrade) {
        const contractAddress = deployedAddresses[contractName];
        const expectedClassHash = classHashes[contractName];

        if (!contractAddress || contractAddress === '') {
            console.log(`${contractName} not deployed yet, skipping.`);
            continue;
        }

        try {
            // Get the current class hash of the deployed contract
            const currentClassHash = await provider.getClassHashAt(contractAddress);

            if (currentClassHash !== expectedClassHash) {
                console.log(`${contractName} needs upgrade (current: ${currentClassHash}, expected: ${expectedClassHash})`);
                
                // Check if the expected class hash exists, if not declare it
                try {
                    await provider.getClassByHash(expectedClassHash);
                } catch (error) {
                    console.log(`Declaring expected class hash ${expectedClassHash} for ${contractName}...`);
                    const { sierra, casm } = contractArtifacts[contractName];
                    await declareContract(account, contractName, sierra, casm);
                }

                await upgradeContract(account, contractName, contractAddress, expectedClassHash);
            } else {
                console.log(`${contractName} is up to date`);
            }
        } catch (error) {
            console.error(`Error processing ${contractName}:`, error);
        }
    }

    console.log('Upgrade process completed');
}

performUpgrades()
    .then(() => console.log('Upgrade completed successfully'))
    .catch(err => console.error('Error during upgrade:', err));