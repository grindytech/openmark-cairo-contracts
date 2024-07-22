import { RpcProvider, Account, Contract, stark, CairoCustomEnum, CairoEnum } from 'starknet';
import * as dotenv from 'dotenv';

dotenv.config();

const provider = new RpcProvider({ nodeUrl: process.env.RPC });
const OPENMARK_ADDRESS = process.env.OPENMARK_ADDRESS;

const types = {
    StarkNetDomain: [
      { name: "name", type: "felt" },
      { name: "version", type: "felt" },
      { name: "chainId", type: "felt" },
    ],
    Order: [
      { name: "nftContract", type: "ContractAddress" },
      { name: "tokenId", type: "u128" },
      { name: "price", type: "u128" },
      { name: "salt", type: "felt" },
      { name: "expiry", type: "u128" },
      { name: "option", type: "OrderType" },
    ],
    Bid: [
      { name: "nftContract", type: "ContractAddress" },
      { name: "amount", type: "u128" },
      { name: "unitPrice", type: "u128" },
      { name: "salt", type: "felt" },
      { name: "expiry", type: "u128" },
    ],
  };
  
  export enum OrderType {
    Buy = "Buy",
    Offer = "Offer",
  }
  
  
  export interface Order {
    nftContract: string,
    tokenId: string,
    price: string,
    salt: string,
    expiry: string,
    option: CairoCustomEnum,
  }

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
   
    test("buy invalid signature should fail", async () => {
        openmarkContract.connect(User);
        let error;
        try {
            let seller = "0x20c29f1c98f3320d56f01c13372c923123c35828bce54f2153aa1cfe61c44f2";
            let option = new CairoCustomEnum({  Buy: "" });

            const order: Order = {
                nftContract: "0x02fcd032721ca83ac833d2e35bd60f1028ebebdcd513388243c0fe53a8e20b9c",
                tokenId: "2",
                price: "3",
                salt: "4",
                expiry: "1721735523000",
                option: option,
              };
              
            let signatures = [
                "0x7a7f6868ad0ea320bdd000f84ef522131dd94719256b3bb0411c216659e948d",
                "0x7128b3e62e4da208cb8ae4796a4edb27e4898f7c95fbf86bf3dbc2306406891"
            ];

            await openmarkContract.buy(seller, order, signatures);
        } catch(err) {
            error = err;
        }
        expect(error).not.toBeNull();
    });
});
