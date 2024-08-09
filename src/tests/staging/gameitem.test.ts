import { RpcProvider, Account, Contract, byteArray, Calldata } from 'starknet';
import * as dotenv from 'dotenv';
dotenv.config();
import { randomBytes } from 'crypto';


const provider = new RpcProvider({ nodeUrl: process.env.RPC });

function generateSalt(length: number): string {
    return randomBytes(length).toString('base64');
}

function compareHex(expected, received) {
    // Remove the '0x' prefix and leading zeros
    const cleanExpected = expected.replace(/^0x0*/, '0x');
    const cleanReceived = received.replace(/^0x0*/, '0x');

    return cleanExpected === cleanReceived;
}


function getCurrentTimestampPlusDays(days: number): number {
    const oneDayInMilliseconds = 24 * 60 * 60 * 1000; // Number of milliseconds in one day
    const currentTimestamp = Date.now(); // Get the current timestamp in milliseconds
    const futureTimestamp = currentTimestamp + (days * oneDayInMilliseconds); // Add specified number of days to the current timestamp
    return futureTimestamp;
}

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const splitTokenIds = (tokenIds, amounts) => {
    const result = [];
    let index = 0;

    for (const amount of amounts) {
        const chunk = tokenIds.slice(index, index + amount);
        result.push(chunk);
        index += amount;
    }

    return result;
}

describe("OpenMark Contract Tests", () => {
    let Owner: Account;
    let gameitemContract: Contract;

    beforeAll(async () => {
        Owner = new Account(provider, process.env.BUYER_ACCOUNT_PUBLIC_KEY, process.env.BUYER_ACCOUNT_PRIVATE_KEY);

        if (!Owner) {
            throw new Error('Account private and public keys must be set in .env file');
        }

        {
            const { abi: testAbi } = await provider.getClassAt(process.env.GAMEITEM_ADDRESS);
            if (testAbi === undefined) {
                throw new Error('No ABI found for the contract.');
            }

            gameitemContract = new Contract(testAbi, process.env.GAMEITEM_ADDRESS, provider).typedv2(testAbi);
        }
    });

    test("safeBatchMint should works", async () => {
        gameitemContract.connect(Owner);
        let tx = await gameitemContract.safeBatchMint(Owner.address, 1);
        const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
        if (txReceipt.isSuccess()) {
            console.log("safeBatchMint Succeed!");

            const listEvents = txReceipt.events;
            let tokenId = listEvents[0].keys[listEvents[0].keys.length - 2];
            console.log("tokenId: ", tokenId);
        }
    });

    test("safeBatchMintWithURIs should works", async () => {
        gameitemContract.connect(Owner);

        let uris = [
            "openmark.io/0",
            "openmark.io/1"
        ];

        const myCall = gameitemContract.populate('safeBatchMintWithURIs', [Owner.address, uris]);
        const res = await gameitemContract.safeBatchMintWithURIs(myCall.calldata);
        const txReceipt = await provider.waitForTransaction(res.transaction_hash);

        if (txReceipt.isSuccess()) {
            console.log("safeBatchMintWithURIs Succeed!");

            const listEvents = txReceipt.events;
            console.log("listEvents: ", listEvents);

            let tokenId = listEvents[0].keys[listEvents[0].keys.length - 2];
            console.log("tokenId: ", tokenId);
        }
    });
});
