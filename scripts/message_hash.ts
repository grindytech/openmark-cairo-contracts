import { WeierstrassSignatureType, ec } from "starknet";
import {Order, Bid, OrderType, getOrderHash, getBidHash} from './utils';
import { SELLER1, SELLER_PRIVATE_KEY1, LOCAL_CHAIN_ID } from "./constants";

const order: Order = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  tokenId: "2",
  payment: "2843359572448325909981641102416202056970710331809754777121873527719804613064",
  price: "3",
  salt: "4",
  expiry: "5",
  option: OrderType.Buy,
};

const bid: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "1",
  payment: "2843359572448325909981641102416202056970710331809754777121873527719804613064",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};


console.log(`account: ${SELLER1};`);

let orderHash = getOrderHash(order, LOCAL_CHAIN_ID, SELLER1);
console.log(`order hash: ${orderHash};`);

let bidHash = getBidHash(bid, LOCAL_CHAIN_ID, SELLER1);
console.log(`bid hash: ${bidHash};`);

const orderSign: WeierstrassSignatureType = ec.starkCurve.sign(orderHash, SELLER_PRIVATE_KEY1);

console.log("order signature r: ", "0x" + orderSign.r.toString(16));
console.log("order  signature s: ", "0x" + orderSign.s.toString(16));

const bidSign: WeierstrassSignatureType = ec.starkCurve.sign(bidHash, SELLER_PRIVATE_KEY1);

console.log("bid signature r: ", "0x" + bidSign.r.toString(16));
console.log("bid  signature s: ", "0x" + bidSign.s.toString(16));
