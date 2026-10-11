// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CreditPassport} from "../src/credit/CreditPassport.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {LoanManager} from "../src/lending/LoanManager.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {RiskEngine} from "../src/risk/RiskEngine.sol";

contract Phase3Test is Test {
    MockERC20 private token;
    CreditPassport private passport;
    RiskEngine private riskEngine;
    LendingPool private pool;
    LoanManager private manager;

    address private borrower = makeAddr("riskBorrower");
    address private attacker = makeAddr("riskAttacker");

    function setUp() public {
        token = new MockERC20("Test Token", "TST", address(this));
        passport = new CreditPassport(address(this));
        riskEngine = new RiskEngine(passport, address(this));
        pool = new LendingPool(token, address(this));
        manager = new LoanManager(pool, token, riskEngine);
        pool.setLoanManager(address(manager));

        token.mint(address(this), 2_000 ether);
        token.mint(borrower, 2_000 ether);
        token.approve(address(pool), type(uint256).max);
        vm.prank(borrower);
        token.approve(address(manager), type(uint256).max);
        pool.deposit(1_500 ether);
    }

    function testEachRiskTierReturnsDocumentedTerms() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);

        passport.updateProfile(borrower, 0, 1);
        (uint16 ltv, uint256 limit) = riskEngine.getBorrowingTerms(borrower);
        assertEq(ltv, 2_500);
        assertEq(limit, 100 ether);

        passport.updateProfile(borrower, 400, 2);
        (ltv, limit) = riskEngine.getBorrowingTerms(borrower);
        assertEq(ltv, 4_000);
        assertEq(limit, 500 ether);

        passport.updateProfile(borrower, 700, 3);
        (ltv, limit) = riskEngine.getBorrowingTerms(borrower);
        assertEq(ltv, 5_000);
        assertEq(limit, 1_000 ether);
    }

    function testRiskTierScoreBoundariesAreEnforced() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);

        passport.updateProfile(borrower, 399, 2);
        vm.expectRevert(RiskEngine.ProfileNotEligible.selector);
        riskEngine.getBorrowingTerms(borrower);

        passport.updateProfile(borrower, 699, 3);
        vm.expectRevert(RiskEngine.ProfileNotEligible.selector);
        riskEngine.getBorrowingTerms(borrower);

        passport.updateProfile(borrower, 400, 2);
        riskEngine.getBorrowingTerms(borrower);
    }

    function testBorrowingEnforcesRiskLtvAndCumulativeLimit() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);
        passport.updateProfile(borrower, 400, 2);

        vm.prank(borrower);
        manager.depositCollateral(1_250 ether);

        vm.prank(borrower);
        manager.borrow(500 ether);

        vm.prank(borrower);
        vm.expectRevert(LoanManager.BorrowLimitExceeded.selector);
        manager.borrow(1);
    }

    function testCumulativeDebtCapCannotBeBypassedByRepayment() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);
        passport.updateProfile(borrower, 400, 2);

        vm.prank(borrower);
        manager.depositCollateral(1_250 ether);

        vm.prank(borrower);
        manager.borrow(500 ether);
        vm.prank(borrower);
        manager.repay(500 ether);

        assertEq(manager.cumulativeBorrowed(borrower), 500 ether);
        vm.prank(borrower);
        vm.expectRevert(LoanManager.BorrowLimitExceeded.selector);
        manager.borrow(1);
    }

    function testPartialRepaymentDoesNotRestoreCumulativeBorrowCapacity() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);
        passport.updateProfile(borrower, 400, 2);

        vm.prank(borrower);
        manager.depositCollateral(1_250 ether);
        vm.prank(borrower);
        manager.borrow(400 ether);
        vm.prank(borrower);
        manager.repay(100 ether);

        vm.prank(borrower);
        vm.expectRevert(LoanManager.BorrowLimitExceeded.selector);
        manager.borrow(101 ether);
    }

    function testTierChangesUseCurrentTermsWithoutResettingCumulativeBorrowed() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);
        passport.updateProfile(borrower, 400, 2);

        vm.prank(borrower);
        manager.depositCollateral(1_250 ether);
        vm.prank(borrower);
        manager.borrow(500 ether);
        vm.prank(borrower);
        manager.repay(500 ether);

        passport.updateProfile(borrower, 700, 3);
        vm.prank(borrower);
        manager.borrow(500 ether);
        assertEq(manager.cumulativeBorrowed(borrower), 1_000 ether);

        passport.updateProfile(borrower, 0, 1);
        vm.prank(borrower);
        vm.expectRevert(LoanManager.BorrowLimitExceeded.selector);
        manager.borrow(1);
    }

    function testLowerTierLtvBoundaryRejectsBorrowingAboveCollateralTerms() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);
        passport.updateProfile(borrower, 0, 1);
        riskEngine.setRiskTerms(1, 0, 2_500, 1_000 ether);

        vm.prank(borrower);
        manager.depositCollateral(400 ether);

        vm.prank(borrower);
        manager.borrow(100 ether);

        vm.prank(borrower);
        vm.expectRevert(LoanManager.LtvExceeded.selector);
        manager.borrow(1);
    }

    function testUnregisteredBorrowerCannotUseRiskTerms() public {
        vm.prank(attacker);
        vm.expectRevert(RiskEngine.NotRegistered.selector);
        manager.borrow(1 ether);
    }

    function testRiskParameterUpdatesAreOwnerOnlyAndImmediate() public {
        vm.prank(borrower);
        passport.registerPassport();
        passport.setCreditUpdater(address(this), true);
        passport.updateProfile(borrower, 800, 3);

        vm.prank(attacker);
        vm.expectRevert();
        riskEngine.setRiskTerms(3, 900, 4_500, 50 ether);

        riskEngine.setRiskTerms(3, 900, 4_500, 50 ether);
        vm.expectRevert(RiskEngine.ProfileNotEligible.selector);
        riskEngine.getBorrowingTerms(borrower);

        passport.updateProfile(borrower, 900, 3);
        (uint16 ltv, uint256 limit) = riskEngine.getBorrowingTerms(borrower);
        assertEq(ltv, 4_500);
        assertEq(limit, 50 ether);
    }

    function testInvalidRiskParametersRevert() public {
        vm.expectRevert(RiskEngine.InvalidRiskTier.selector);
        riskEngine.setRiskTerms(0, 0, 2_500, 100 ether);

        vm.expectRevert(RiskEngine.InvalidScore.selector);
        riskEngine.setRiskTerms(1, 1_001, 2_500, 100 ether);

        vm.expectRevert(RiskEngine.InvalidLtv.selector);
        riskEngine.setRiskTerms(1, 0, 5_001, 100 ether);

        vm.expectRevert(RiskEngine.InvalidBorrowLimit.selector);
        riskEngine.setRiskTerms(1, 0, 2_500, 0);
    }
}
