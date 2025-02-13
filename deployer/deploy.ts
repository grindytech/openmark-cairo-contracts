import { RpcProvider, Account, Contract, json, RawArgs, constants, RawCalldata, Calldata, CallData } from 'starknet';
import dotenv from 'dotenv';
dotenv.config();

// connect provider
const RPC = process.env.RPC;
const provider = new RpcProvider({ nodeUrl: RPC });

const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY ? process.env.OZ_ACCOUNT_PRIVATE_KEY : "";
const Deployer: string = '0x0575d4e20cC1f9beE77530922532a586BC1142B7CDc2AFe175321bcb6aF4E8A2';

async function do_deploy(name: string, classHash: string, constructorData: RawArgs) {
    const account0 = new Account(provider, Deployer, privateKey0, undefined, constants.TRANSACTION_VERSION.V3);

    // read abi of Test contract
    const { abi: openMarkAbi } = await provider.getClassByHash(classHash);
    if (openMarkAbi === undefined) {
        throw new Error('no abi.');
    }

    const contractCallData: CallData = new CallData(openMarkAbi);
    const contractConstructor: Calldata = contractCallData.compile('constructor', constructorData);

    const deployResponse = await account0.deployContract({
        classHash: classHash,
        constructorCalldata: contractConstructor,
    });

    console.log(`✅ ${name}:`, deployResponse.address);
    return deployResponse.address;
}

async function deploy() {
    // Deploy OpenMark
    {
        const classHash = "0x068446a9836985055ca23b35471072c430fbdd608a607f572c879ba0a93d11db";
        const paymentTokens: RawCalldata = [
            '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',   // ETH
            '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d',   // STRK
            '0x06866b14e2d9d4a48c8ae11f4711a6f976d528215239e9f49850be8f22f8c0cf'    // OMC
        ];

        const data: RawArgs = {
            owner: Deployer,
            paymentTokens: paymentTokens,
        }

        await do_deploy("OpenMark", classHash, data);
    }

    // Deploy Open Collection
    {
        const classHash = "0x7c636c5ad9dc2e3e6cb1c69f86ddf61b1445a8730fbefa9601680887f55c2fd";

        const data: RawArgs = {
            name: "Open Collection",
            symbol: "OC",
        }

        await do_deploy("OpenCollection", classHash, data);
    }

    // Deploy Open Launchpad
    {
        const classHash = "0x64f551defc1fb8a41215bc1cb90049851841c80b7194b7b7298f022a29b3dca";
        const paymentTokens: RawCalldata = [
            '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',   // ETH
            '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d',   // STRK
            '0x06866b14e2d9d4a48c8ae11f4711a6f976d528215239e9f49850be8f22f8c0cf'    // OMC
        ];
        const commission = 300; // 3%
        const selector_classhash = "0x7caf7f84f8c41b2a0f3c86da0006899da63012703e6c4c221e188ab2f1a4fe4";
        const batch_selector_classhash = "0x52b7488853817656b7796e41a0c28ff5575cbfa61edc65b563d3c926113a648";

        const data: RawArgs = {
            owner: Deployer,
            paymentTokens: paymentTokens,
            commission: commission,
            selector_classhash: selector_classhash,
            batch_selector_classhash: batch_selector_classhash,
        }

        await do_deploy("OpenLaunchpad", classHash, data);
    }

    // Deploy OERC721Factory
    {
        const classHash = "0x2b8a9e0980313a4fd7cec1701c0d02f8e3f36b636f5bf6864be8910aae83fca";
        const collection_classhash = "0x7d889be98093c3742271bdbae74c86379cd34ccaff9a41acb962156788833e7";

        const data: RawArgs = {
            owner: Deployer,
            collection_classhash: collection_classhash,
        }

        await do_deploy("OERC721Factory", classHash, data);
    }

    // Deploy OERC1155Factory
    {
        const classHash = "0x30152963371cb46ceaa935833bec7d73f93c26ba1ec928b09a3c6d9d152d9dc";
        const collection_classhash = "0x20943dea90b583fac7d80a95a9721f7073fcb4aa238dc23ee1bcb0265dad6e3";


        const data: RawArgs = {
            owner: Deployer,
            collection_classhash: collection_classhash,
        }

        await do_deploy("OERC1155Factory", classHash, data);
    }

    // Deploy LaunchpadFactory
    {
        const classHash = "0x9ee3e71483dc16455fe7644b490853b1ea388da3a55b6c007524930c06bc01";
        const launchpad_classhash = "0x78e2453bfac501977ba95d2d04bcc7a8e96111523c907aacac9ecd8777aef81";
        const commission = 0;
        const selector_classhash = "0x7caf7f84f8c41b2a0f3c86da0006899da63012703e6c4c221e188ab2f1a4fe4";
        const batch_selector_classhash = "0x52b7488853817656b7796e41a0c28ff5575cbfa61edc65b563d3c926113a648";

        const data: RawArgs = {
            owner: Deployer,
            launchpad_classhash: launchpad_classhash,
            commission: commission,
            selector_classhash: selector_classhash,
            batch_selector_classhash: batch_selector_classhash,
        }

        await do_deploy("LaunchpadFactory", classHash, data);
    }
}

deploy().then().catch(err => {
    console.log("error: ", err);
});