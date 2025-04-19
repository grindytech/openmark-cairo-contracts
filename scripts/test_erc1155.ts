import {
    RpcProvider, Account, Contract, json, RawArgs,
    constants, RawCalldata, RPC, Calldata, CallData, num,
    stark, Call
} from 'starknet';
import dotenv from 'dotenv';
dotenv.config();

// connect provider
const RPC_URL = process.env.RPC;
const provider = new RpcProvider({ nodeUrl: RPC_URL });

const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY ? process.env.OZ_ACCOUNT_PRIVATE_KEY : "";
const OWNER: string = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';
const OERC1155_FACTORY = '0x4474e27a47379d20e700739b26634de2d828fc532f16dfc2cd6962a458e6e51';

async function executeTx(account: Account, address: string, entrypoint: string, calldata: any) {
    const { abi: testAbi } = await provider.getClassAt(address);
    if (testAbi === undefined) {
        throw new Error('no abi.');
    }
    const contract = new Contract(testAbi, address, provider);
    contract.connect(account);

    // Batch mint
    const myCall = contract.populate(entrypoint, calldata);
    const maxQtyGasAuthorized = 18000n; // max quantity of gas authorized
    const maxPriceAuthorizeForOneGas = 30n * 10n ** 13n; // max FRI authorized to pay 1 gas (1 FRI=10**-18 STRK)
    console.log('max authorized cost =', maxQtyGasAuthorized * maxPriceAuthorizeForOneGas, 'FRI');
    const { transaction_hash: txH } = await account.execute(myCall, {
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
        console.log(`${entrypoint} succeed: ${txH}`);
    } else {
        console.log(txR);
    }
}

async function deploy() {
    const account = new Account(provider, OWNER, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    const ID = 10000000001;
    let ERC1155Instance = "0x00cc15decf3d473a43a21c625771a750a7324186e8142f61a1d713598af7a2c6";
    // Create ERC1155 Instance
    {
        await executeTx(account, OERC1155_FACTORY, 'createInstance', [ID, OWNER, "OMERC1155", "OM1155", "openmark.io", 100, 0]);
        {
            const { abi: testAbi } = await provider.getClassAt(OERC1155_FACTORY);
            if (testAbi === undefined) {
                throw new Error('no abi.');
            }
            const contract = new Contract(testAbi, OERC1155_FACTORY, provider);
            const result = await contract.getInstance(ID);
            ERC1155Instance = '0x' + result.toString(16);
        }
    }

    console.log("ERC1155Instance: ", ERC1155Instance);

    await executeTx(account, ERC1155Instance, 'mintBatch', [OWNER, [0, 1, 2], [100, 100, 100], []]);

    await executeTx(account, ERC1155Instance, 'safeBatchTransferFrom', [OWNER, "0x03B2d9654644463e040f4264103333179cd9c24E30628fa0B39fab933f58168a", [0, 1, 2], [10, 10, 10], []]);
}

deploy().then().catch(err => {
    console.log("error: ", err);
});