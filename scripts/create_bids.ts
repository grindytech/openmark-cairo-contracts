import { BigNumberish, WeierstrassSignatureType, ec, encode, typedData } from "starknet";

const types = {
  StarkNetDomain: [
    { name: "name", type: "felt" },
    { name: "version", type: "felt" },
    { name: "chainId", type: "felt" },
  ],
  Bid: [
    { name: "nftContract", type: "ContractAddress" },
    { name: "amount", type: "u128" },
    { name: "unitPrice", type: "u128" },
    { name: "salt", type: "felt" },
    { name: "expiry", type: "u128" },
  ],
};


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


function getBidHash(myStruct: Bid, chainId: string, owner: BigNumberish): string {
  return typedData.getMessageHash(getBidData(myStruct, chainId), owner);
}

function getBidData(myStruct: Bid, chainId: string): typedData.TypedData {
  return {
    types,
    primaryType: "Bid",
    domain: getDomain(chainId),
    message: { ...myStruct },
  };
}

const bid1: Bid = {
  nftContract: "2341477128991891436918010733589720897462482571482832085806644138878406121386",
  amount: "1",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const bid2: Bid = {
  nftContract: "2341477128991891436918010733589720897462482571482832085806644138878406121386",
  amount: "2",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const bid3: Bid = {
  nftContract: "2341477128991891436918010733589720897462482571482832085806644138878406121386",
  amount: "3",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};



const buyerPrivateKey1 = '0x1234567890123456789';
const buyerPrivateKey2 = '0x12345678901234567891';
const buyerPrivateKey3 = '0x12345678901234567892';

const buyer1: BigNumberish = ec.starkCurve.getStarkKey(buyerPrivateKey1);
const buyer2: BigNumberish = ec.starkCurve.getStarkKey(buyerPrivateKey2);
const buyer3: BigNumberish = ec.starkCurve.getStarkKey(buyerPrivateKey3);

let msgHash1 = getBidHash(bid1, "393402133025997798000961", buyerPrivateKey1);
let msgHash2 = getBidHash(bid2, "393402133025997798000961", buyerPrivateKey2);
let msgHash3 = getBidHash(bid3, "393402133025997798000961", buyerPrivateKey3);

console.log(`buyer1: ${buyer1};`);
console.log(`buyer2: ${buyer2};`);
console.log(`buyer3: ${buyer3};`);

const signature1: WeierstrassSignatureType = ec.starkCurve.sign(msgHash1, buyerPrivateKey1);
const signature2: WeierstrassSignatureType = ec.starkCurve.sign(msgHash2, buyerPrivateKey2);
const signature3: WeierstrassSignatureType = ec.starkCurve.sign(msgHash3, buyerPrivateKey3);

console.log("signature1 r: ", "0x" + signature1.r.toString(16));
console.log("signature1 s: ", "0x" + signature1.s.toString(16));

console.log("signature2 r: ", "0x" + signature2.r.toString(16));
console.log("signature2 s: ", "0x" + signature2.s.toString(16));

console.log("signature3 r: ", "0x" + signature3.r.toString(16));
console.log("signature3 s: ", "0x" + signature3.s.toString(16));
