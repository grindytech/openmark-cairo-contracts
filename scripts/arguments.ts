import {byteArray, ByteArray} from 'starknet';

console.log("Name: ",  byteArray.byteArrayFromString("OpenMark"));
console.log("Symbol:",  byteArray.byteArrayFromString("OM"));
console.log("Base URI: ",  byteArray.byteArrayFromString("ipfs://QmUMGWrnyeuPkARUYMUf5U9NWo8uihRGnhLH5yk3rzdUX6/"));

const uriByteArray = {
   data: ["0x697066733a2f2f516d554d4757726e796575506b415255594d55663555394e"],
   pending_word: '0x576f3875696852476e684c4835796b33727a645558362f30',
   pending_word_len: 0x18
}

console.log("uriByteArray:", byteArray.stringFromByteArray(uriByteArray));
