import { BigNumberish, WeierstrassSignatureType, ec } from "starknet";
import {Order, Bid, OrderType, getOrderHash, getBidHash} from './utils';

const order: Order = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  tokenId: "2",
  price: "3",
  salt: "4",
  expiry: "5",
  option: OrderType.Buy,
};

const bid: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "1",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const privateKey = '0x1234567890123456789';
const starknetPublicKey = ec.starkCurve.getStarkKey(privateKey);
const account: BigNumberish = starknetPublicKey;
console.log(`account: ${account};`);

let orderHash = getOrderHash(order, "393402133025997798000961", account);
console.log(`order hash: ${orderHash};`);

let bidHash = getBidHash(bid, "393402133025997798000961", account);
console.log(`bid hash: ${bidHash};`);

const orderSign: WeierstrassSignatureType = ec.starkCurve.sign(orderHash, privateKey);

console.log("order signature r: ", "0x" + orderSign.r.toString(16));
console.log("order  signature s: ", "0x" + orderSign.s.toString(16));

const bidSign: WeierstrassSignatureType = ec.starkCurve.sign(bidHash, privateKey);

console.log("bid signature r: ", "0x" + bidSign.r.toString(16));
console.log("bid  signature s: ", "0x" + bidSign.s.toString(16));
