import { BigNumberish, WeierstrassSignatureType, ec, encode, typedData } from "starknet";
import {Order, OrderType, getOrderHash} from './utils';

const order: Order = {
  nftContract: "2341477128991891436918010733589720897462482571482832085806644138878406121386",
  tokenId: "3",
  price: "3",
  salt: "4",
  expiry: "5",
  option: OrderType.Offer,
};

const sellerPrivateKey = '0x1234567890987654321';
const buyerPrivateKey = '0x1234567890123456789';
const sellerPublicKey = ec.starkCurve.getStarkKey(sellerPrivateKey);
const buyerPublicKey = ec.starkCurve.getStarkKey(buyerPrivateKey);
const seller: BigNumberish = sellerPublicKey;
const buyer: BigNumberish = buyerPublicKey;

let msgHash = getOrderHash(order, "393402133025997798000961", buyer);
console.log(`seller: ${seller};`);
console.log(`buyer: ${buyer};`);

const signature: WeierstrassSignatureType = ec.starkCurve.sign(msgHash, buyerPrivateKey);

console.log("signature r: ", "0x" + signature.r.toString(16));
console.log("signature s: ", "0x" + signature.r.toString(16));

console.log("signature r: ", "0x" + signature.r.toString(16));
console.log("signature s: ", "0x" + signature.s.toString(16));
