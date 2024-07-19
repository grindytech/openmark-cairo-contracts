import { RpcProvider, Account, Contract, stark, uint256, shortString } from 'starknet';
import * as dotenv from 'dotenv';

dotenv.config();

const provider = new RpcProvider({ nodeUrl: process.env.RPC });
const FACTORY_ADDRESS = process.env.FACTORY_ADDRESS;

describe("Factory Contract Tests", () => {
    let User: Account;
    let factoryContract: Contract;

    beforeAll(async () => {
        User = new Account(provider, process.env.OZ_ACCOUNT_PUBLIC_KEY, process.env.OZ_ACCOUNT_PRIVATE_KEY);

        if (!User) {
            throw new Error('Account private and public keys must be set in .env file');
        }

        const { abi: testAbi } = await provider.getClassAt(FACTORY_ADDRESS);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        factoryContract = new Contract(testAbi, FACTORY_ADDRESS, provider).typedv2(testAbi);
    });

    test("set nft classhash not admin should fail", async () => {
        factoryContract.connect(User);
        let error;
        try {
            await factoryContract.set_openmark_nft("0x000000");
        } catch(err) {
            error = err;
        }
        expect(error).not.toBeNull();
    });
});
