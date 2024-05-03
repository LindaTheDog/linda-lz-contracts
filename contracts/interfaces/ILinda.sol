// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILinda {
    function isExcludedFromFees(address account) external view returns (bool);
}