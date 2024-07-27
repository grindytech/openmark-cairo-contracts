import { RpcProvider, Account, Contract, stark, uint256, shortString, CairoCustomEnum, num, constants } from 'starknet';
import * as dotenv from 'dotenv';
dotenv.config();
import { randomBytes } from 'crypto';
import { createOrderSignature } from './common';


const provider = new RpcProvider({ nodeUrl: process.env.RPC });

function generateSalt(length: number): string {
    return randomBytes(length).toString('base64');
}


describe("OpenMark Contract Tests", () => {
    let Seller: Account;
    let Buyer: Account;
    let openmarkContract: Contract;
    let paymentContract: Contract;
    let nftContract: Contract;

    beforeAll(async () => {
        Seller = new Account(provider, process.env.SELLER_ACCOUNT_PUBLIC_KEY, process.env.SELLER_ACCOUNT_PRIVATE_KEY);
        Buyer = new Account(provider, process.env.BUYER_ACCOUNT_PUBLIC_KEY, process.env.BUYER_ACCOUNT_PRIVATE_KEY);

        if (!Seller || !Buyer) {
            throw new Error('Account private and public keys must be set in .env file');
        }

        {
            const { abi: testAbi } = await provider.getClassAt(process.env.OPENMARK_ADDRESS);
            if (testAbi === undefined) {
                throw new Error('No ABI found for the contract.');
            }

            openmarkContract = new Contract(testAbi, process.env.OPENMARK_ADDRESS, provider).typedv2(testAbi);
        }
        {
            const { abi: testAbi } = await provider.getClassAt(process.env.PAYMENT_ADDRESS);
            if (testAbi === undefined) {
                throw new Error('No ABI found for the contract.');
            }

            paymentContract = new Contract(testAbi, process.env.PAYMENT_ADDRESS, provider).typedv2(testAbi);
        }
        {
            const { abi: testAbi } = await provider.getClassAt(process.env.NFT_ADDRESS);
            if (testAbi === undefined) {
                throw new Error('No ABI found for the contract.');
            }

            nftContract = new Contract(testAbi, process.env.NFT_ADDRESS, provider).typedv2(testAbi);
        }
    });

    test("buy should works", async () => {
        const salt = generateSalt(16); // Generates a 16-byte salt
        let tokenId = "0x0";
        let price = "1000000000000000000"; // 1 token

        // Create and Approve NFT OpenMark
        {
            nftContract.connect(Seller);
            let createTx = await nftContract.safe_mint(Seller.address);
            const createReceipt = await provider.waitForTransaction(createTx.transaction_hash);
            if (createReceipt.isSuccess()) {
                const listEvents = createReceipt.events;
                tokenId = listEvents[0].keys[listEvents[0].keys.length - 2];
                console.log("tokenId: ", tokenId);
            }

            let approve_tx = await nftContract.approve(openmarkContract.address, tokenId);
            const approveReceipt = await provider.waitForTransaction(approve_tx.transaction_hash);
            if (approveReceipt.isSuccess()) {
                console.log("Approve NFT Succeed!");
            }
        }

        // Buyer Approve OpenMark payment token
        {
            paymentContract.connect(Buyer);
            let tx = await paymentContract.approve(openmarkContract.address, price);
            const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("Approve Payment Succeed!");
            }
        }

        // Buy
        {
            openmarkContract.connect(Buyer);
            let order = {
                nftContract: nftContract.address,
                tokenId: tokenId,
                payment: paymentContract.address,
                price: price,
                salt: salt,
                expiry: "1721735523000",
                option: 0,
            };

            let signatures = await createOrderSignature(order, Seller, constants.StarknetChainId.SN_SEPOLIA);

            let cairo_order = {
                nftContract: nftContract.address,
                tokenId: tokenId,
                payment: paymentContract.address,
                price: price,
                salt: salt,
                expiry: "1721735523000",
                option: new CairoCustomEnum({ Buy: "" }),
            };

            openmarkContract.connect(Buyer);
            let tx = await openmarkContract.buy(Seller.address, cairo_order, [signatures.r, signatures.s]);
            const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("Buy Succeed: ", tx.transaction_hash);
            }
        }

        expect(true).toBe(true);
    });
});
