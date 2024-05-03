// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Mode Network Sequencer Fee Sharing
interface IFeeSharing {
    function register(address _recipient) external returns (uint256 tokenId);
}