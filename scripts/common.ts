import { RpcProvider, Account, constants, CallData, RawArgs, json } from 'starknet';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

const RPC = process.env.RPC || 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: RPC });

export async function do_deploy(name: string, publicKey, privateKey, classHash: string, constructorData: RawArgs): Promise<string> {
    const account0 = new Account(provider, publicKey, privateKey, undefined, constants.TRANSACTION_VERSION.V3);

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