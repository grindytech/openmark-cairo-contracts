import { BigNumberish, WeierstrassSignatureType, ec } from "starknet";
import { Bid, getBidHash } from './utils';
import {
  BUYER1, BUYER2, BUYER3,
  BUYER_PRIVATE_KEY1, BUYER_PRIVATE_KEY2, BUYER_PRIVATE_KEY3
} from './constants';

const bid1: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "1",
  payment: "2843359572448325909981641102416202056970710331809754777121873527719804613064",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const bid2: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "2",
  payment: "2843359572448325909981641102416202056970710331809754777121873527719804613064",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const bid3: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "3",
  payment: "2843359572448325909981641102416202056970710331809754777121873527719804613064",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

let msgHash1 = getBidHash(bid1, "393402133025997798000961", BUYER1);
let msgHash2 = getBidHash(bid2, "393402133025997798000961", BUYER2);
let msgHash3 = getBidHash(bid3, "393402133025997798000961", BUYER3);

console.log(`buyer1: ${BUYER1};`);
console.log(`buyer2: ${BUYER2};`);
console.log(`buyer3: ${BUYER3};`);

const signature1: WeierstrassSignatureType = ec.starkCurve.sign(msgHash1, BUYER_PRIVATE_KEY1);
const signature2: WeierstrassSignatureType = ec.starkCurve.sign(msgHash2, BUYER_PRIVATE_KEY2);
const signature3: WeierstrassSignatureType = ec.starkCurve.sign(msgHash3, BUYER_PRIVATE_KEY3);

console.log("signature1 r: ", "0x" + signature1.r.toString(16));
console.log("signature1 s: ", "0x" + signature1.s.toString(16));

console.log("signature2 r: ", "0x" + signature2.r.toString(16));
console.log("signature2 s: ", "0x" + signature2.s.toString(16));

console.log("signature3 r: ", "0x" + signature3.r.toString(16));
console.log("signature3 s: ", "0x" + signature3.s.toString(16));
