import { RpcProvider, Account, Contract, CairoCustomEnum, num, constants } from 'starknet';
import * as dotenv from 'dotenv';
dotenv.config();
import { randomBytes } from 'crypto';
import { createOrderSignature, createBidSignature, SignedBid } from './common';


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
    let Seller1: Account;
    let Seller2: Account;
    let Seller3: Account;
    let Buyer: Account;
    let openmarkContract: Contract;
    let paymentContract: Contract;
    let nftContract: Contract;

    beforeAll(async () => {
        Seller1 = new Account(provider, process.env.SELLER_ACCOUNT_PUBLIC_KEY1, process.env.SELLER_ACCOUNT_PRIVATE_KEY1);
        Seller2 = new Account(provider, process.env.SELLER_ACCOUNT_PUBLIC_KEY2, process.env.SELLER_ACCOUNT_PRIVATE_KEY2);
        Seller3 = new Account(provider, process.env.SELLER_ACCOUNT_PUBLIC_KEY3, process.env.SELLER_ACCOUNT_PRIVATE_KEY3);
        Buyer = new Account(provider, process.env.BUYER_ACCOUNT_PUBLIC_KEY, process.env.BUYER_ACCOUNT_PRIVATE_KEY);

        if (!Seller1 || !Seller3 || !Seller3 || !Buyer) {
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
        let price = "1000000000000000000";
        let expiry = getCurrentTimestampPlusDays(1);
        // Create and Approve NFT OpenMark
        {
            nftContract.connect(Seller1);
            let createTx = await nftContract.safe_mint(Seller1.address);
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
            let order = {
                nftContract: nftContract.address,
                tokenId: tokenId,
                payment: paymentContract.address,
                price: price,
                salt: salt,
                expiry: expiry.toString(),
                option: 0,
            };

            let signatures = await createOrderSignature(order, Seller1, constants.StarknetChainId.SN_SEPOLIA);

            let cairo_order = {
                nftContract: nftContract.address,
                tokenId: tokenId,
                payment: paymentContract.address,
                price: price,
                salt: salt,
                expiry: expiry.toString(),
                option: new CairoCustomEnum({ Buy: "" }),
            };

            let buyerBeforeBalance = await paymentContract.balanceOf(Buyer.address);
            let sellerBeforeBalance = await paymentContract.balanceOf(Seller1.address);

            openmarkContract.connect(Buyer);
            let tx = await openmarkContract.buy(Seller1.address, cairo_order, [signatures.r, signatures.s]);
            const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("Buy Succeed: ", tx.transaction_hash);
            }

            // verify balances and ownership
            let buyerAfterBalance = await paymentContract.balanceOf(Buyer.address);
            let sellerAfterBalance = await paymentContract.balanceOf(Seller1.address);

            let nft_owner = await nftContract.owner_of(tokenId);

            expect(buyerAfterBalance).toEqual(buyerBeforeBalance - BigInt(price));
            expect(sellerAfterBalance).toEqual(sellerBeforeBalance + BigInt(price));
            expect(compareHex(num.toHexString(nft_owner), Buyer.address)).toEqual(true);
        }

    });

    test("acceptOffer should works", async () => {
        const salt = generateSalt(16); // Generates a 16-byte salt
        let tokenId = "0x0";
        let price = "1000000000000000000"; // 1 token
        let expiry = getCurrentTimestampPlusDays(1);

        // Create and Approve NFT OpenMark
        {
            nftContract.connect(Seller1);
            let createTx = await nftContract.safe_mint(Seller1.address);
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

        // Accept Offer
        {
            let order = {
                nftContract: nftContract.address,
                tokenId: tokenId,
                payment: paymentContract.address,
                price: price,
                salt: salt,
                expiry: expiry.toString(),
                option: 1,
            };

            let signatures = await createOrderSignature(order, Buyer, constants.StarknetChainId.SN_SEPOLIA);

            let cairo_order = {
                nftContract: nftContract.address,
                tokenId: tokenId,
                payment: paymentContract.address,
                price: price,
                salt: salt,
                expiry: expiry.toString(),
                option: new CairoCustomEnum({ Offer: "" }),
            };

            let buyerBeforeBalance = await paymentContract.balanceOf(Buyer.address);
            let sellerBeforeBalance = await paymentContract.balanceOf(Seller1.address);

            openmarkContract.connect(Seller1);
            let tx = await openmarkContract.acceptOffer(Buyer.address, cairo_order, [signatures.r, signatures.s]);
            const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("acceptOffer Succeed: ", tx.transaction_hash);
            }

            // verify balances and ownership
            let buyerAfterBalance = await paymentContract.balanceOf(Buyer.address);
            let sellerAfterBalance = await paymentContract.balanceOf(Seller1.address);

            let nft_owner = await nftContract.owner_of(tokenId);

            expect(buyerAfterBalance).toEqual(buyerBeforeBalance - BigInt(price));
            expect(sellerAfterBalance).toEqual(sellerBeforeBalance + BigInt(price));
            expect(compareHex(num.toHexString(nft_owner), Buyer.address)).toEqual(true);
        }
    });

    test("fillBids should works", async () => {
        const salt = generateSalt(16); // Generates a 16-byte salt
        let tokenId = "0x0";
        let price = "1000000000000000000"; // 1 token
        let expiry = getCurrentTimestampPlusDays(1);
        let amount = 1;

        // Create and Approve NFT OpenMark
        {
            nftContract.connect(Seller1);
            let createTx = await nftContract.safe_mint(Seller1.address);
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

        // Fill Bids
        {
            let bid = {
                nftContract: nftContract.address,
                payment: paymentContract.address,
                amount: amount.toString(),
                unitPrice: price,
                salt: salt,
                expiry: expiry.toString(),
            };

            let signatures = await createBidSignature(bid, Buyer, constants.StarknetChainId.SN_SEPOLIA);

            let bids: SignedBid[] = [
                {
                    bidder: Buyer.address,
                    bid: bid,
                    signature: [signatures.r, signatures.s],
                }
            ]

            let buyerBeforeBalance = await paymentContract.balanceOf(Buyer.address);
            let sellerBeforeBalance = await paymentContract.balanceOf(Seller1.address);

            openmarkContract.connect(Seller1);
            let tx = await openmarkContract.fillBids(bids, nftContract.address,
                [tokenId], paymentContract.address, price);

            const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("fillBids Succeed: ", tx.transaction_hash);
            }

            // verify balances and ownership
            let buyerAfterBalance = await paymentContract.balanceOf(Buyer.address);
            let sellerAfterBalance = await paymentContract.balanceOf(Seller1.address);

            let nft_owner = await nftContract.owner_of(tokenId);

            expect(buyerAfterBalance).toEqual(buyerBeforeBalance - BigInt(price));
            expect(sellerAfterBalance).toEqual(sellerBeforeBalance + BigInt(price));
            expect(compareHex(num.toHexString(nft_owner), Buyer.address)).toEqual(true);
        }
    });

    test("Mass fillBids should works", async () => {
        let NUM_OF_BID = 3;
        let NFT_AMOUNT = 6;
        let amounts = [2, 1, 3];

        let tokenIds = [];
        let price = BigInt(1000000000000000000); // 1 token
        let expiry = getCurrentTimestampPlusDays(1);
        let Sellers = [Seller1, Seller2, Seller3];

        // Create and Approve NFT OpenMark
        {
            for (let i = 0; i < NUM_OF_BID; i++) {

                nftContract.connect(Sellers[i]);
                let createTx = await nftContract.safe_batch_mint(Sellers[i].address, amounts[i]);
                const createReceipt = await provider.waitForTransaction(createTx.transaction_hash);
                if (createReceipt.isSuccess()) {
                    const listEvents = createReceipt.events;
                    let ids = listEvents
                        .filter(event => event.keys.length === 5)
                        .map(event => event.keys[3]);
                    tokenIds.push(...ids);
                }

                let approve_tx = await nftContract.set_approval_for_all(openmarkContract.address, true);

                const approveReceipt = await provider.waitForTransaction(approve_tx.transaction_hash);
                if (approveReceipt.isSuccess()) {
                    console.log(`Approve NFT Succeed!`);
                }
            }
            console.log("tokenIds: ", tokenIds);

        }

        // Buyer Approve OpenMark payment token
        {
            paymentContract.connect(Buyer);
            let tx = await paymentContract.approve(openmarkContract.address, price * BigInt(NFT_AMOUNT));
            const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("Approve Payment Succeed!");
            }
        }

        // Fill Bids
        {
            let bids = []
            for (let i = 0; i < NUM_OF_BID; i++) {
                const salt = generateSalt(16); // Generates a 16-byte salt

                let bid = {
                    nftContract: nftContract.address,
                    payment: paymentContract.address,
                    amount: amounts[i].toString(16),
                    unitPrice: price.toString(),
                    salt: salt,
                    expiry: expiry.toString(),
                };

                let signatures = await createBidSignature(bid, Buyer, constants.StarknetChainId.SN_SEPOLIA);

                bids.push(
                    {
                        bidder: Buyer.address,
                        bid: bid,
                        signature: [signatures.r, signatures.s],
                    }
                )
            }

            let buyerBalance = await paymentContract.balanceOf(Buyer.address);
            let sellersBalances = [];
            for (let i = 0; i < NUM_OF_BID; i++) {
                sellersBalances.push(await paymentContract.balanceOf(Sellers[i].address));
            }

            let token_ids = splitTokenIds(tokenIds, amounts);
            let lastTX;
            for (let i = 0; i < NUM_OF_BID; i++) {
                openmarkContract.connect(Sellers[i]);
                lastTX = await openmarkContract.fillBids(bids, nftContract.address, token_ids[i], paymentContract.address, price);
            }

            let txReceipt = await provider.waitForTransaction(lastTX.transaction_hash);
            if (txReceipt.isSuccess()) {
                console.log("fillBids Succeed!");
            }

            for (const tokenId of tokenIds) {
                let nft_owner = await nftContract.owner_of(tokenId);
                expect(compareHex(num.toHexString(nft_owner), Buyer.address)).toEqual(true);
            }

            expect(buyerBalance).toEqual((await paymentContract.balanceOf(Buyer.address)) + (BigInt(NFT_AMOUNT) * price));
            for (let i = 0; i < NUM_OF_BID; i++) {
                expect(sellersBalances[i]).toEqual((await paymentContract.balanceOf(Sellers[i].address)) - (BigInt(amounts[i]) * price));
            }
        }
    });
});
