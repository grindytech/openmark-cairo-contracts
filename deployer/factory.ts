// SPDX-License-Identifier: GPL-3.0
// OpenMark Factory Class Hash Update Script
// Copyright (c) Grindy Technologies 2025
// See LICENSE file for full terms.

/// # OpenMark Factory Class Hash Update Script
///
/// This script manages the class hash updates for OpenMark factory contracts on StarkNet:
/// - Checks current class hashes of deployed factory contracts using get_classhash
/// - Compares them with expected class hashes from classhashes.json
/// - Updates factory class hashes if they differ using set_classhash
/// - Supports OERC721Factory, OERC1155Factory, and StageFactory contracts

import { RpcProvider, Account, constants, json, CallData, Contract } from 'starknet';
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

const factoryManagedClasses: { [key: string]: string[] } = {
    'OERC721Factory': ['OERC721'],
    'OERC1155Factory': ['OERC1155'],
    'StageFactory': ['StageSelector', 'StageBatchSelector', 'StageVRF']
};

async function updateFactoryClassHash(
    account: Account,
    contractName: string,
    contractAddress: string,
    classHashes: ClassHashRecord
) {
    const { abi } = await provider.getClassAt(contractAddress);
    if (abi === undefined) {
        throw new Error('No ABI found for the contract.');
    }

    const factoryContract = new Contract(abi, contractAddress, provider).typedv2(abi);
    factoryContract.connect(account);

    const currentClassHashes = await factoryContract.get_classhash();
    const expectedClassHashes = factoryManagedClasses[contractName].map(className =>
        classHashes[className]
    );

    const needsUpdate = currentClassHashes.some((hash: string, index: number) =>
        hash !== expectedClassHashes[index]
    );

    if (needsUpdate) {
        console.log(`${contractName} needs class hash update`);
        const set_classhash_tx = await factoryContract.set_classhash(expectedClassHashes);
        const receipt = await provider.waitForTransaction(set_classhash_tx.transaction_hash);
        if (receipt.isSuccess()) {
            console.log(`✅ ${contractName} class hashes updated - Tx: ${set_classhash_tx.transaction_hash}`);
        }
    } else {
        console.log(`${contractName} class hashes are up to date`);
    }
}

async function updateFactoryClassHashes() {
    const account = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);
    const classHashes: ClassHashRecord = json.parse(fs.readFileSync('./classhashes.json', 'utf8'));
    const deployedAddresses: DeployedRecord = json.parse(fs.readFileSync('./deployed.json', 'utf8'));

    const factoryContracts = ['OERC721Factory', 'OERC1155Factory', 'StageFactory'];

    for (const contractName of factoryContracts) {
        const contractAddress = deployedAddresses[contractName];
        if (contractAddress && contractAddress !== '') {
            await updateFactoryClassHash(account, contractName, contractAddress, classHashes);
        } else {
            console.log(`${contractName} not deployed, skipping`);
        }
    }
}

updateFactoryClassHashes()
    .then(() => console.log('Factory class hash updates completed successfully'))
    .catch(err => console.error('Error during factory updates:', err));