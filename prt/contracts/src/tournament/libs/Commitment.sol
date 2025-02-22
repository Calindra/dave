// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.17;

import "../../CanonicalConstants.sol";
import "../../Tree.sol";
import "../../Machine.sol";

// import "./Merkle.sol";

library Commitment {
    using Tree for Tree.Node;
    using Commitment for Tree.Node;

    function requireState(
        Tree.Node commitment,
        uint64 treeHeight,
        uint256 position,
        Machine.Hash state,
        bytes32[] calldata hashProof
    ) internal pure {
        Tree.Node expectedCommitment =
            getRoot(Machine.Hash.unwrap(state), treeHeight, position, hashProof);

        require(commitment.eq(expectedCommitment), "commitment state mismatch");
    }

    function isEven(uint256 x) private pure returns (bool) {
        return x % 2 == 0;
    }

    function getRoot(
        bytes32 leaf,
        uint64 treeHeight,
        uint256 position,
        bytes32[] calldata siblings
    ) internal pure returns (Tree.Node) {
        assert(treeHeight == siblings.length);

        for (uint256 i = 0; i < treeHeight; i++) {
            if (isEven(position >> i)) {
                leaf = keccak256(abi.encodePacked(leaf, siblings[i]));
            } else {
                leaf = keccak256(abi.encodePacked(siblings[i], leaf));
            }
        }

        return Tree.Node.wrap(leaf);
    }

    function requireFinalState(
        Tree.Node commitment,
        uint64 treeHeight,
        Machine.Hash finalState,
        bytes32[] calldata hashProof
    ) internal pure {
        Tree.Node expectedCommitment = getRootForLastLeaf(
            treeHeight, Machine.Hash.unwrap(finalState), hashProof
        );

        require(
            commitment.eq(expectedCommitment),
            "commitment last state doesn't match"
        );
    }

    function getRootForLastLeaf(
        uint64 treeHeight,
        bytes32 leaf,
        bytes32[] calldata siblings
    ) internal pure returns (Tree.Node) {
        assert(treeHeight == siblings.length);

        for (uint256 i = 0; i < treeHeight; i++) {
            leaf = keccak256(abi.encodePacked(siblings[i], leaf));
        }

        return Tree.Node.wrap(leaf);
    }
}
