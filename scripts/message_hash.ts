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
  Bid: [
    { name: "nftContract", type: "ContractAddress" },
    { name: "amount", type: "u128" },
    { name: "unitPrice", type: "u128" },
    { name: "salt", type: "felt" },
    { name: "expiry", type: "u128" },
  ],
};

enum OrderType {
  Buy,
  Offer,
}


interface Order {
  nftContract: string,
  tokenId: string,
  price: string,
  salt: string,
  expiry: string,
  option: OrderType,
}

interface Bid {
  nftContract: string,
  amount: string,
  unitPrice: string,
  salt: string,
  expiry: string,
}

function getDomain(chainId: string): typedData.StarkNetDomain {
  return {
    name: "OpenMark",
    version: "1",
    chainId,
  };
}

function getOrderHash(myStruct: Order, chainId: string, owner: BigNumberish): string {
  return typedData.getMessageHash(getOrderData(myStruct, chainId), owner);
}

function getBidHash(myStruct: Bid, chainId: string, owner: BigNumberish): string {
  return typedData.getMessageHash(getBidData(myStruct, chainId), owner);
}

// Needed to reproduce the same structure as:
// https://github.com/0xs34n/starknet.js/blob/1a63522ef71eed2ff70f82a886e503adc32d4df9/__mocks__/typedDataStructArrayExample.json
function getOrderData(myStruct: Order, chainId: string): typedData.TypedData {
  return {
    types,
    primaryType: "Order",
    domain: getDomain(chainId),
    message: { ...myStruct },
  };
}

function getBidData(myStruct: Bid, chainId: string): typedData.TypedData {
  return {
    types,
    primaryType: "Bid",
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

const bid: Bid = {
  nftContract: "1",
  amount: "2",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const privateKey = '0x1234567890987654321';
const starknetPublicKey = ec.starkCurve.getStarkKey(privateKey);
const account: BigNumberish = starknetPublicKey;
console.log(`account: ${account};`);

let orderHash = getOrderHash(order, "393402133025997798000961", account);
console.log(`order hash: ${orderHash};`);

let bidHash = getBidHash(bid, "393402133025997798000961", account);
console.log(`bid hash: ${bidHash};`);

const orderSign: WeierstrassSignatureType = ec.starkCurve.sign(orderHash, privateKey);

console.log("order signature r: 0x", orderSign.r.toString(16));
console.log("order  signature s: 0x", orderSign.s.toString(16));

const bidSign: WeierstrassSignatureType = ec.starkCurve.sign(bidHash, privateKey);

console.log("bid signature r: 0x", bidSign.r.toString(16));
console.log("bid  signature s: 0x", bidSign.s.toString(16));
