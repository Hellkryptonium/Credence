// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ILoanManager
/// @notice Interface for collateralized borrower loan lifecycle operations.
interface ILoanManager {
    function depositCollateral(uint256 amount) external;

    function withdrawCollateral(uint256 amount) external;

    function borrow(uint256 amount) external;

    function repay(uint256 amount) external;
}
