import { BigNumberish, StarknetDomain, typedData, TypedData } from "starknet";

const types = {
  StarkNetDomain: [
    { name: "name", type: "felt" },
    { name: "version", type: "felt" },
    { name: "chainId", type: "felt" },
  ],
  Order: [
    { name: "nftContract", type: "ContractAddress" },
    { name: "tokenId", type: "u128" },
    { name: "payment", type: "ContractAddress" },
    { name: "price", type: "u128" },
    { name: "salt", type: "felt" },
    { name: "expiry", type: "u128" },
    { name: "option", type: "OrderType" },
  ],
  Bid: [
    { name: "nftContract", type: "ContractAddress" },
    { name: "amount", type: "u128" },
    { name: "payment", type: "ContractAddress" },
    { name: "unitPrice", type: "u128" },
    { name: "salt", type: "felt" },
    { name: "expiry", type: "u128" },
  ],
};

export enum OrderType {
  Buy,
  Offer,
}

export interface Order {
  nftContract: string,
  tokenId: string,
  payment: string,
  price: string,
  salt: string,
  expiry: string,
  option: OrderType,
}

export interface Bid {
  nftContract: string,
  amount: string,
  payment: string,
  unitPrice: string,
  salt: string,
  expiry: string,
}

function getDomain(chainId: string): StarknetDomain {
  return {
    name: "OpenMark",
    version: "1",
    chainId,
  };
}

export function getOrderHash(myStruct: Order, chainId: string, owner: BigNumberish): string {
  return typedData.getMessageHash(getOrderData(myStruct, chainId), owner);
}

export function getBidHash(myStruct: Bid, chainId: string, owner: BigNumberish): string {
  return typedData.getMessageHash(getBidData(myStruct, chainId), owner);
}

// Needed to reproduce the same structure as:
// https://github.com/0xs34n/starknet.js/blob/1a63522ef71eed2ff70f82a886e503adc32d4df9/__mocks__/typedDataStructArrayExample.json
function getOrderData(myStruct: Order, chainId: string): TypedData {
  return {
    types,
    primaryType: "Order",
    domain: getDomain(chainId),
    message: { ...myStruct },
  };
}

function getBidData(myStruct: Bid, chainId: string): TypedData {
  return {
    types,
    primaryType: "Bid",
    domain: getDomain(chainId),
    message: { ...myStruct },
  };
}
