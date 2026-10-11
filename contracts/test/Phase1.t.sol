// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {LoanManager} from "../src/lending/LoanManager.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";

contract Phase1Test is Test {
    MockERC20 private token;
    LendingPool private pool;
    LoanManager private manager;

    address private lender = makeAddr("lender");
    address private borrower = makeAddr("borrower");
    address private attacker = makeAddr("attacker");

    uint256 private constant LIQUIDITY = 1_000 ether;
    uint256 private constant COLLATERAL = 200 ether;

    function setUp() public {
        token = new MockERC20("Test Token", "TST", address(this));
        pool = new LendingPool(token, address(this));
        manager = new LoanManager(pool, token);
        pool.setLoanManager(address(manager));

        token.mint(lender, LIQUIDITY);
        token.mint(borrower, COLLATERAL);
        token.mint(attacker, 100 ether);

        vm.prank(lender);
        token.approve(address(pool), type(uint256).max);
        vm.prank(borrower);
        token.approve(address(manager), type(uint256).max);
    }

    function testLenderDepositAndWithdrawAvailableLiquidity() public {
        vm.startPrank(lender);
        pool.deposit(LIQUIDITY);
        pool.withdraw(400 ether);
        vm.stopPrank();

        assertEq(pool.deposits(lender), 600 ether);
        assertEq(pool.totalLiquidity(), 600 ether);
        assertEq(token.balanceOf(lender), 400 ether);
    }

    function testBorrowAndRepay() public {
        _depositLiquidity();
        _depositCollateral();

        vm.prank(borrower);
        manager.borrow(100 ether);

        (uint256 collateral, uint256 debt) = manager.loans(borrower);
        assertEq(collateral, COLLATERAL);
        assertEq(debt, 100 ether);
        assertEq(pool.totalBorrowed(), 100 ether);
        assertEq(token.balanceOf(borrower), 100 ether);

        vm.prank(borrower);
        manager.repay(100 ether);

        (, debt) = manager.loans(borrower);
        assertEq(debt, 0);
        assertEq(pool.totalBorrowed(), 0);
        assertEq(token.balanceOf(address(pool)), pool.availableLiquidity());
        _assertPoolSolvent();
    }

    function testPartialRepaymentUpdatesBothDebtLedgers() public {
        _depositLiquidity();
        _depositCollateral();

        vm.prank(borrower);
        manager.borrow(100 ether);
        vm.prank(borrower);
        manager.repay(40 ether);

        (, uint256 debt) = manager.loans(borrower);
        assertEq(debt, 60 ether);
        assertEq(pool.totalBorrowed(), 60 ether);
        assertEq(pool.availableLiquidity(), 940 ether);
        _assertPoolSolvent();
    }

    function testCollateralCanOnlyBeWithdrawnAfterFullRepayment() public {
        _depositLiquidity();
        _depositCollateral();
        vm.prank(borrower);
        manager.borrow(100 ether);

        vm.prank(borrower);
        vm.expectRevert(LoanManager.DebtOutstanding.selector);
        manager.withdrawCollateral(COLLATERAL);

        vm.prank(borrower);
        manager.repay(100 ether);

        vm.prank(borrower);
        manager.withdrawCollateral(COLLATERAL);
        (uint256 collateral,) = manager.loans(borrower);
        assertEq(collateral, 0);
    }

    function testUnauthorizedPoolOperationsRevert() public {
        vm.prank(attacker);
        vm.expectRevert(LendingPool.NotLoanManager.selector);
        pool.borrow(attacker, 1 ether);

        vm.prank(attacker);
        vm.expectRevert(LendingPool.NotLoanManager.selector);
        pool.repay(1 ether);
    }

    function testInvalidAmountsRevert() public {
        vm.prank(lender);
        vm.expectRevert(LendingPool.InvalidAmount.selector);
        pool.deposit(0);

        vm.prank(borrower);
        vm.expectRevert(LoanManager.InvalidAmount.selector);
        manager.depositCollateral(0);
    }

    function testInsufficientLiquidityReverts() public {
        _depositCollateral();
        vm.prank(borrower);
        vm.expectRevert(LendingPool.InsufficientAvailableLiquidity.selector);
        manager.borrow(1 ether);
    }

    function testLtvLimitReverts() public {
        _depositLiquidity();
        _depositCollateral();

        vm.prank(borrower);
        vm.expectRevert(LoanManager.LtvExceeded.selector);
        manager.borrow(101 ether);
    }

    function testLenderCannotWithdrawBorrowedLiquidity() public {
        _depositLiquidity();
        _depositCollateral();
        vm.prank(borrower);
        manager.borrow(100 ether);

        vm.prank(lender);
        vm.expectRevert(LendingPool.InsufficientAvailableLiquidity.selector);
        pool.withdraw(LIQUIDITY);
    }

    function testMultipleLendersWithdrawOnlyTheirAvailableDeposits() public {
        address secondLender = makeAddr("secondLender");
        token.mint(secondLender, 400 ether);

        vm.prank(lender);
        pool.deposit(600 ether);
        vm.prank(secondLender);
        token.approve(address(pool), type(uint256).max);
        vm.prank(secondLender);
        pool.deposit(400 ether);

        _depositCollateral();
        vm.prank(borrower);
        manager.borrow(100 ether);

        vm.prank(lender);
        pool.withdraw(500 ether);
        vm.prank(secondLender);
        pool.withdraw(400 ether);

        assertEq(pool.availableLiquidity(), 0);
        assertEq(pool.deposits(lender), 100 ether);
        assertEq(pool.deposits(secondLender), 0);
        _assertPoolSolvent();

        vm.prank(lender);
        vm.expectRevert(LendingPool.InsufficientAvailableLiquidity.selector);
        pool.withdraw(1 ether);
    }

    function testWithdrawExactAvailableLiquidityAndRejectOneMore() public {
        _depositLiquidity();
        _depositCollateral();
        vm.prank(borrower);
        manager.borrow(100 ether);

        vm.prank(lender);
        pool.withdraw(900 ether);
        assertEq(pool.availableLiquidity(), 0);

        vm.prank(lender);
        vm.expectRevert(LendingPool.InsufficientAvailableLiquidity.selector);
        pool.withdraw(1 ether);
    }

    function testZeroAddressAndOneTimeConfigurationReverts() public {
        vm.expectRevert(LendingPool.InvalidAddress.selector);
        new LendingPool(MockERC20(address(0)), address(this));

        vm.expectRevert(LendingPool.InvalidAddress.selector);
        new LendingPool(token, address(0));

        vm.expectRevert(LoanManager.InvalidAddress.selector);
        new LoanManager(ILendingPool(address(0)), token);

        vm.expectRevert(LoanManager.InvalidAddress.selector);
        new LoanManager(pool, MockERC20(address(0)));

        LendingPool freshPool = new LendingPool(token, address(this));
        vm.expectRevert(LendingPool.InvalidAddress.selector);
        freshPool.setLoanManager(address(0));
        freshPool.setLoanManager(address(manager));
        vm.expectRevert(LendingPool.LoanManagerAlreadySet.selector);
        freshPool.setLoanManager(address(manager));

        vm.expectRevert();
        new MockERC20("Invalid", "INV", address(0));
    }

    function testPoolSolvencyInvariantAcrossLifecycle() public {
        _depositLiquidity();
        _depositCollateral();
        _assertPoolSolvent();

        vm.prank(borrower);
        manager.borrow(100 ether);
        _assertPoolSolvent();

        vm.prank(borrower);
        manager.repay(40 ether);
        _assertPoolSolvent();

        vm.prank(lender);
        pool.withdraw(940 ether);
        _assertPoolSolvent();
    }

    function testFeeOnTransferUsesActualReceivedAmounts() public {
        FeeOnTransferToken feeToken = new FeeOnTransferToken();
        LendingPool feePool = new LendingPool(feeToken, address(this));
        LoanManager feeManager = new LoanManager(feePool, feeToken);
        feePool.setLoanManager(address(feeManager));

        feeToken.mint(lender, LIQUIDITY);
        feeToken.mint(borrower, COLLATERAL);
        vm.prank(lender);
        feeToken.approve(address(feePool), type(uint256).max);
        vm.prank(borrower);
        feeToken.approve(address(feeManager), type(uint256).max);

        vm.prank(lender);
        feePool.deposit(LIQUIDITY);
        vm.prank(borrower);
        feeManager.depositCollateral(COLLATERAL);

        assertEq(feePool.totalLiquidity(), 900 ether);
        (uint256 collateral,) = feeManager.loans(borrower);
        assertEq(collateral, 180 ether);

        vm.prank(borrower);
        feeManager.borrow(90 ether);
        feeToken.mint(borrower, 100 ether);

        vm.prank(borrower);
        feeManager.repay(90 ether);

        (, uint256 debt) = feeManager.loans(borrower);
        assertEq(debt, 17.1 ether);
        assertEq(feePool.totalBorrowed(), debt);
        assertEq(feeToken.balanceOf(address(feePool)), feePool.availableLiquidity());
    }

    function testOnlyOwnerCanConfigureLoanManager() public {
        LendingPool freshPool = new LendingPool(token, address(this));

        vm.prank(attacker);
        vm.expectRevert();
        freshPool.setLoanManager(address(manager));
    }

    function _depositLiquidity() private {
        vm.prank(lender);
        pool.deposit(LIQUIDITY);
    }

    function _depositCollateral() private {
        vm.prank(borrower);
        manager.depositCollateral(COLLATERAL);
    }

    function _assertPoolSolvent() private view {
        assertLe(pool.totalBorrowed(), pool.totalLiquidity());
        assertEq(pool.availableLiquidity(), pool.totalLiquidity() - pool.totalBorrowed());
        assertGe(token.balanceOf(address(pool)) + pool.totalBorrowed(), pool.totalLiquidity());
    }
}

contract FeeOnTransferToken is ERC20 {
    constructor() ERC20("Fee Token", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = value / 10;
        super._update(from, address(0), fee);
        super._update(from, to, value - fee);
    }
}
