// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IRiskEngine
/// @notice Interface for validating credit profiles and resolving borrowing terms.
interface IRiskEngine {
    function getBorrowingTerms(address borrower) external view returns (uint16 maxLtvBps, uint256 maxBorrowAmount);
}
