import {
    BigNumberish, StarknetDomain, typedData,
    TypedData, WeierstrassSignatureType, Account,
} from "starknet";

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
    payment: string,
    amount: string,
    unitPrice: string,
    salt: string,
    expiry: string,
}

export interface SignedBid {
    bidder: string,
    bid: Bid,
    signature: bigint[]
}

function getDomain(chainId: string): StarknetDomain {
    return {
        name: "OpenMark",
        version: "1",
        chainId,
    };
}


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


export async function createOrderSignature(order: Order, seller: Account, chainID): Promise<WeierstrassSignatureType> {
    let signature = await seller.signMessage(getOrderData(order, chainID)) as WeierstrassSignatureType;
    return signature;
}

export async function createBidSignature(bid: Bid, seller: Account, chainID): Promise<WeierstrassSignatureType> {
    let signature = await seller.signMessage(getBidData(bid, chainID)) as WeierstrassSignatureType;
    return signature;
}