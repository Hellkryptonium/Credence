// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";

/// @title LoanManager
/// @notice Coordinates 1:1 collateralized loans against a configured lending pool.
contract LoanManager is ILoanManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LTV_BPS = 5_000;
    uint256 private constant BPS = 10_000;

    ILendingPool public immutable pool;
    IERC20 public immutable collateralToken;

    struct Loan {
        uint256 collateral;
        uint256 debt;
    }

    mapping(address borrower => Loan loan) public loans;

    error InvalidAddress();
    error InvalidAmount();
    error LtvExceeded();
    error DebtOutstanding();
    error InsufficientCollateral();
    error CollateralAssetMismatch();

    constructor(ILendingPool pool_, IERC20 collateralToken_) {
        if (address(pool_) == address(0) || address(collateralToken_) == address(0)) revert InvalidAddress();
        if (pool_.asset() != address(collateralToken_)) revert CollateralAssetMismatch();
        pool = pool_;
        collateralToken = collateralToken_;
    }

    /// @notice Locks collateral for the caller's loan.
    function depositCollateral(uint256 amount) external override nonReentrant {
        if (amount == 0) revert InvalidAmount();
        uint256 balanceBefore = collateralToken.balanceOf(address(this));
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = collateralToken.balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert InvalidAmount();
        loans[msg.sender].collateral += received;
    }

    /// @notice Withdraws unlocked collateral after the caller has repaid all debt.
    function withdrawCollateral(uint256 amount) external override nonReentrant {
        if (amount == 0) revert InvalidAmount();
        Loan storage loan = loans[msg.sender];
        if (loan.debt != 0) revert DebtOutstanding();
        if (loan.collateral < amount) revert InsufficientCollateral();
        loan.collateral -= amount;
        collateralToken.safeTransfer(msg.sender, amount);
    }

    /// @notice Borrows pool assets within the caller's 50% collateral value limit.
    function borrow(uint256 amount) external override nonReentrant {
        if (amount == 0) revert InvalidAmount();
        Loan storage loan = loans[msg.sender];
        if ((loan.debt + amount) * BPS > loan.collateral * MAX_LTV_BPS) revert LtvExceeded();
        pool.borrow(msg.sender, amount);
        loan.debt += amount;
    }

    /// @notice Repays caller debt using the pool's asset token.
    function repay(uint256 amount) external override nonReentrant {
        if (amount == 0) revert InvalidAmount();
        Loan storage loan = loans[msg.sender];
        if (amount > loan.debt) revert InvalidAmount();
        IERC20 asset = IERC20(pool.asset());
        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = asset.balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert InvalidAmount();
        asset.forceApprove(address(pool), received);
        uint256 creditedAmount = pool.repay(received);
        loan.debt -= creditedAmount;
    }
}
