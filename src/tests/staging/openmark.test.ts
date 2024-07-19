import { RpcProvider, Account, Contract, stark, uint256, shortString } from 'starknet';
import * as dotenv from 'dotenv';

dotenv.config();

const provider = new RpcProvider({ nodeUrl: process.env.RPC });
const OPENMARK_ADDRESS = process.env.OPENMARK_ADDRESS;

describe("OpenMark Contract Tests", () => {
    let Admin: Account;
    let User: Account;
    let openmarkContract: Contract;

    beforeAll(async () => {
        Admin = new Account(provider, process.env.ADMIN_ACCOUNT_PUBLIC_KEY, process.env.ADMIN_ACCOUNT_PRIVATE_KEY);
        User = new Account(provider, process.env.OZ_ACCOUNT_PUBLIC_KEY, process.env.OZ_ACCOUNT_PRIVATE_KEY);

        if (!Admin || !User) {
            throw new Error('Account private and public keys must be set in .env file');
        }

        const { abi: testAbi } = await provider.getClassAt(OPENMARK_ADDRESS);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        openmarkContract = new Contract(testAbi, OPENMARK_ADDRESS, provider).typedv2(testAbi);
    });

    test("set the commission with admin should works", async () => {
        openmarkContract.connect(Admin);
        await openmarkContract.set_commission(0n);

        await provider.waitForBlock();

        const commission = await openmarkContract.get_commission();
        expect(commission).toEqual(0n);
    });

    test("set the commission not admin should fail", async () => {
        openmarkContract.connect(User);
        let error;
        try {
            await openmarkContract.set_commission(200n);
        } catch(err) {
            error = err;
        }
        const commission = await openmarkContract.get_commission();
        expect(commission).toEqual(0n);
        expect(error).not.toBeNull();
    });
});
