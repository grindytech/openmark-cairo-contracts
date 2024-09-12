import { BUYER1, BUYER2, BUYER3 } from "./constants";
import { StandardMerkleTree } from "@ericnordelo/strk-merkle-tree";

const values = [
    [BUYER1],
    [BUYER2],
    [BUYER3]
];

const tree = StandardMerkleTree.of(values, ["ContractAddress"]);

console.log('Merkle Root:', tree.root);

for (const [i, v] of tree.entries()) {
    const proof = tree.getProof(i);
    console.log('Value:', v);
    console.log('Proof:', proof);
}