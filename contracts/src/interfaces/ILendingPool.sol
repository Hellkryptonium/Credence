// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ILendingPool
/// @notice Interface for lender liquidity and authorized loan accounting.
interface ILendingPool {
    function asset() external view returns (address);

    function totalLiquidity() external view returns (uint256);

    function totalBorrowed() external view returns (uint256);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function borrow(address recipient, uint256 amount) external;

    function repay(uint256 amount) external returns (uint256 creditedAmount);
}
