import { BigNumberish, WeierstrassSignatureType, ec, encode, typedData } from "starknet";

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
};

enum OrderType {
  Buy,
  Sell,
}


interface Order {
  nftContract: string,
  tokenId: string,
  price: string,
  salt: string,
  expiry: string,
  option: OrderType,
}

function getDomain(chainId: string): typedData.StarkNetDomain {
  return {
    name: "OpenMark",
    version: "1",
    chainId,
  };
}

function getTypedDataHash(myStruct: Order, chainId: string, owner: BigNumberish): string {
  return typedData.getMessageHash(getTypedData(myStruct, chainId), owner);
}

// Needed to reproduce the same structure as:
// https://github.com/0xs34n/starknet.js/blob/1a63522ef71eed2ff70f82a886e503adc32d4df9/__mocks__/typedDataStructArrayExample.json
function getTypedData(myStruct: Order, chainId: string): typedData.TypedData {
  return {
    types,
    primaryType: "Order",
    domain: getDomain(chainId),
    message: { ...myStruct },
  };
}

const order: Order = {
  nftContract: "1",
  tokenId: "2",
  price: "3",
  salt: "4",
  expiry: "5",
  option: OrderType.Buy,
};

const privateKey = '0x1234567890987654321';
const starknetPublicKey = ec.starkCurve.getStarkKey(privateKey);
const account: BigNumberish = starknetPublicKey;

let msgHash = getTypedDataHash(order, "393402133025997798000961", account);
console.log(`account: ${account};`);
console.log(`test msgHash: ${msgHash};`);

const signature: WeierstrassSignatureType = ec.starkCurve.sign(msgHash, privateKey);


console.log("signature r: ", signature.r.toString(16));
console.log("signature s: ", signature.s.toString(16));
