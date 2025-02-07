import { RpcProvider, Account, Contract, json, stark, uint256, shortString } from 'starknet';

// connect provider
const provider = new RpcProvider({ baseUrl: 'http://127.0.0.1:5050/rpc' });
// connect your account. To adapt to your own account:
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY;
const account0Address: string = '0x123....789';
const account0 = new Account(provider, account0Address, privateKey0);

// Declare & deploy Test contract in devnet
const compiledTestSierra = json.parse(
  fs.readFileSync('./compiledContracts/test.sierra').toString('ascii')
);
const compiledTestCasm = json.parse(
  fs.readFileSync('./compiledContracts/test.casm').toString('ascii')
);
const deployResponse = await account0.declareAndDeploy({
  contract: compiledTestSierra,
  casm: compiledTestCasm,
});

// Connect the new contract instance:
const myTestContract = new Contract(
  compiledTestSierra.abi,
  deployResponse.deploy.contract_address,
  provider
);
console.log('Test Contract Class Hash =', deployResponse.declare.class_hash);
console.log('✅ Test Contract connected at =', myTestContract.address);