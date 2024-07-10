// import {ByteCode} from 'starknet';

// export function strToFeltArr(str: string): BigInt[] {
//     const size = Math.ceil(str.length / 31);
//     const arr = Array(size);

//     let offset = 0;
//     for (let i = 0; i < size; i++) {
//         const substr = str.substring(offset, offset + 31).split("");
//         const ss = substr.reduce(
//             (memo, c) => memo + c.charCodeAt(0).toString(16),
//             ""
//         );
//         arr[i] = BigInt("0x" + ss);
//         offset += 31;
//     }
//     return arr;
// }

// export function strToFelt(str: string): BigInt {
//     let hexString = "0x";

//     for (let i = 0; i < str.length; i++) {
//         hexString += str.charCodeAt(i).toString(16).padStart(2, '0');
//     }

//     return BigInt(hexString);
// }


// console.log("Name: ", "0x" + byteArrayFromString("OpenMark NFT").toString(16));
// console.log("Symbol: ", "0x" + strToFelt("OM").toString(16));
// console.log("Base URI: ", "0x" + strToFelt("https://nft-api.openmark.io/").toString(16));