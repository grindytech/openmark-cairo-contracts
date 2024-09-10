import {  WeierstrassSignatureType, ec } from "starknet";
import {Order, OrderType, getOrderHash} from './utils';
import {BUYER1, BUYER_PRIVATE_KEY1, LOCAL_CHAIN_ID} from './constants';

const order: Order = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  tokenId: "3",
  payment: "2843359572448325909981641102416202056970710331809754777121873527719804613064",
  price: "3",
  salt: "4",
  expiry: "5",
  option: OrderType.Offer,
};

let msgHash = getOrderHash(order, LOCAL_CHAIN_ID, BUYER1);
console.log(`buyer: ${BUYER1};`);

const signature: WeierstrassSignatureType = ec.starkCurve.sign(msgHash, BUYER_PRIVATE_KEY1);

console.log("signature r: ", "0x" + signature.r.toString(16));
console.log("signature s: ", "0x" + signature.s.toString(16));
