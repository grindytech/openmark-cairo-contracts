import {
    RpcProvider, Account, Contract, json, RawArgs,
    constants, RawCalldata, RPC, Calldata, CallData, num
} from 'starknet';
import dotenv from 'dotenv';
dotenv.config();

// connect provider
const RPC_URL = process.env.RPC;
const provider = new RpcProvider({ nodeUrl: RPC_URL });

const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY ? process.env.OZ_ACCOUNT_PRIVATE_KEY : "";
const Deployer: string = '0x065eed23D0432b65900F957dc207C1FC65E48cF8007bA7c02BB0c6b7FE0848aB';
const OERC1155_FACTORY = '0x4474e27a47379d20e700739b26634de2d828fc532f16dfc2cd6962a458e6e51';

async function deploy() {
    const account0 = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);


    const ID = 102;
    // Create ERC1155 Instance
    {
        const { abi: testAbi } = await provider.getClassAt(OERC1155_FACTORY);
        if (testAbi === undefined) {
            throw new Error('no abi.');
        }
        const myTestContract = new Contract(testAbi, OERC1155_FACTORY, provider);
        myTestContract.connect(account0);

        // // Interactions with the contract with meta-class
        // const myCall = myTestContract.populate('createInstance', [ID, Deployer, "OMERC1155", "OM1155", "openmark.io", 100, 0]);
        // const res = await myTestContract.createInstance(myCall.calldata);

        // console.log("Factory create Instance: ", res.transaction_hash);
        // await provider.waitForTransaction(res.transaction_hash);

        const myCall = myTestContract.populate('createInstance', [ID, Deployer, "OMERC1155", "OM1155", "openmark.io", 100, 0]);
        const maxQtyGasAuthorized = 18000n; // max quantity of gas authorized
        const maxPriceAuthorizeForOneGas = 30n * 10n ** 13n; // max FRI authorized to pay 1 gas (1 FRI=10**-18 STRK)
        console.log('max authorized cost =', maxQtyGasAuthorized * maxPriceAuthorizeForOneGas, 'FRI');
        const { transaction_hash: txH } = await account0.execute(myCall, {
            version: 3,
            maxFee: 10 ** 18,
            feeDataAvailabilityMode: RPC.EDataAvailabilityMode.L1,
            tip: 10 ** 13,
            paymasterData: [],
            resourceBounds: {
                l1_gas: {
                    max_amount: num.toHex(maxQtyGasAuthorized),
                    max_price_per_unit: num.toHex(maxPriceAuthorizeForOneGas),
                },
                l2_gas: {
                    max_amount: num.toHex(0),
                    max_price_per_unit: num.toHex(0),
                },
            },
        });
        const txR = await provider.waitForTransaction(txH);
        if (txR.isSuccess()) {
            console.log('Paid fee =', txR.actual_fee);
        }
    }


}

deploy().then().catch(err => {
    console.log("error: ", err);
});