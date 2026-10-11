// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";

/// @title LendingPool
/// @notice Holds lender liquidity and tracks funds authorized for outstanding loans.
contract LendingPool is ILendingPool, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 private immutable _asset;
    address public loanManager;
    uint256 public override totalLiquidity;
    uint256 public override totalBorrowed;
    mapping(address lender => uint256 amount) public deposits;

    error InvalidAddress();
    error InvalidAmount();
    error LoanManagerAlreadySet();
    error NotLoanManager();
    error InsufficientDeposit();
    error InsufficientAvailableLiquidity();

    event LoanManagerSet(address indexed loanManager);
    event LiquidityDeposited(address indexed lender, uint256 amount);
    event LiquidityWithdrawn(address indexed lender, uint256 amount);
    event FundsBorrowed(address indexed borrower, uint256 amount);
    event FundsRepaid(uint256 amount);

    constructor(IERC20 asset_, address initialOwner) Ownable(initialOwner) {
        if (address(asset_) == address(0) || initialOwner == address(0)) revert InvalidAddress();
        _asset = asset_;
    }

    /// @notice Returns the ERC20 lent by this pool.
    function asset() external view override returns (address) {
        return address(_asset);
    }

    /// @notice Assigns the only contract allowed to account for loans.
    function setLoanManager(address loanManager_) external onlyOwner {
        if (loanManager_ == address(0)) revert InvalidAddress();
        if (loanManager != address(0)) revert LoanManagerAlreadySet();
        loanManager = loanManager_;
        emit LoanManagerSet(loanManager_);
    }

    /// @notice Adds caller-owned tokens to the pool's available liquidity.
    function deposit(uint256 amount) external override nonReentrant {
        if (amount == 0) revert InvalidAmount();
        uint256 balanceBefore = _asset.balanceOf(address(this));
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = _asset.balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert InvalidAmount();
        deposits[msg.sender] += received;
        totalLiquidity += received;
        emit LiquidityDeposited(msg.sender, received);
    }

    /// @notice Withdraws caller-owned liquidity that is not currently borrowed.
    function withdraw(uint256 amount) external override nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (deposits[msg.sender] < amount) revert InsufficientDeposit();
        if (availableLiquidity() < amount) revert InsufficientAvailableLiquidity();
        deposits[msg.sender] -= amount;
        totalLiquidity -= amount;
        _asset.safeTransfer(msg.sender, amount);
        emit LiquidityWithdrawn(msg.sender, amount);
    }

    /// @notice Sends available liquidity to a borrower and records its debt.
    function borrow(address recipient, uint256 amount) external override nonReentrant {
        if (msg.sender != loanManager) revert NotLoanManager();
        if (recipient == address(0) || amount == 0) revert InvalidAmount();
        if (availableLiquidity() < amount) revert InsufficientAvailableLiquidity();
        totalBorrowed += amount;
        _asset.safeTransfer(recipient, amount);
        emit FundsBorrowed(recipient, amount);
    }

    /// @notice Records repayment received from the loan manager.
    function repay(uint256 amount) external override nonReentrant returns (uint256 creditedAmount) {
        if (msg.sender != loanManager) revert NotLoanManager();
        if (amount == 0 || amount > totalBorrowed) revert InvalidAmount();
        uint256 balanceBefore = _asset.balanceOf(address(this));
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        creditedAmount = _asset.balanceOf(address(this)) - balanceBefore;
        if (creditedAmount == 0 || creditedAmount > totalBorrowed) revert InvalidAmount();
        totalBorrowed -= creditedAmount;
        emit FundsRepaid(creditedAmount);
    }

    /// @notice Returns liquidity that can currently be withdrawn or borrowed.
    function availableLiquidity() public view returns (uint256) {
        return totalLiquidity - totalBorrowed;
    }
}
