import { RpcProvider, Account, Contract, stark, uint256, shortString } from 'starknet';
import * as dotenv from 'dotenv';

dotenv.config();

const provider = new RpcProvider({ nodeUrl: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7" });
const OPENMARK_ADDRESS = "0x0566d2e3943410cb0b67037174ff3ded452270d37e3c471707e89f1789901fb8";

describe("OpenMark Contract Tests", () => {
    let account: Account;
    let openmarkContract: Contract;

    beforeAll(async () => {
        const privateKey = process.env.OZ_ACCOUNT_PRIVATE_KEY;
        const accountAddress = process.env.OZ_ACCOUNT_PUBLIC_KEY;

        if (!privateKey || !accountAddress) {
            throw new Error('Account private and public keys must be set in .env file');
        }

        account = new Account(provider, accountAddress, privateKey);

        const { abi: testAbi } = await provider.getClassAt(OPENMARK_ADDRESS);
        if (testAbi === undefined) {
            throw new Error('No ABI found for the contract.');
        }

        openmarkContract = new Contract(testAbi, OPENMARK_ADDRESS, provider).typedv2(testAbi);
    });

    test("should get the commission from the OpenMark contract", async () => {
        const commission = await openmarkContract.get_commission();
        console.log("Commission: ", commission);
        expect(commission).toBeDefined();
    });

    // Add more tests as needed
});
