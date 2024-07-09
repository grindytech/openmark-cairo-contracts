import { BigNumberish, WeierstrassSignatureType, ec } from "starknet";
import { Bid, getBidHash} from './utils';

const buyerPrivateKey1 = '0x1234567890123456789';
const buyerPrivateKey2 = '0x12345678901234567891';
const buyerPrivateKey3 = '0x12345678901234567892';

const buyer1: BigNumberish = ec.starkCurve.getStarkKey(buyerPrivateKey1);
const buyer2: BigNumberish = ec.starkCurve.getStarkKey(buyerPrivateKey2);
const buyer3: BigNumberish = ec.starkCurve.getStarkKey(buyerPrivateKey3);

const bid1: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "1",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const bid2: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "2",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

const bid3: Bid = {
  nftContract: "2430974627077655374827931444984473429257053957362777049136691086629713838851",
  amount: "3",
  unitPrice: "3",
  salt: "4",
  expiry: "5",
};

let msgHash1 = getBidHash(bid1, "393402133025997798000961", buyer1);
let msgHash2 = getBidHash(bid2, "393402133025997798000961", buyer2);
let msgHash3 = getBidHash(bid3, "393402133025997798000961", buyer3);

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
