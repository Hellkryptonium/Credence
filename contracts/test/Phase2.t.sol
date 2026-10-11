// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CreditPassport} from "../src/credit/CreditPassport.sol";
import {CreditRegistry} from "../src/credit/CreditRegistry.sol";

contract Phase2Test is Test {
    CreditPassport private passport;

    address private updater = makeAddr("updater");
    address private borrower = makeAddr("borrower");
    address private attacker = makeAddr("attacker");

    function setUp() public {
        passport = new CreditPassport(address(this));
    }

    function testWalletRegistersOwnPassport() public {
        vm.prank(borrower);
        passport.registerPassport();

        CreditRegistry.CreditProfile memory profile = passport.profiles(borrower);
        assertEq(profile.score, 0);
        assertEq(profile.riskTier, 0);
        assertEq(profile.lastUpdated, block.timestamp);
        assertTrue(profile.registered);
        assertTrue(passport.isRegistered(borrower));
    }

    function testDuplicateRegistrationReverts() public {
        vm.startPrank(borrower);
        passport.registerPassport();
        vm.expectRevert(CreditRegistry.AlreadyRegistered.selector);
        passport.registerPassport();
        vm.stopPrank();
    }

    function testOnlyRegisteredWalletCanBeUpdatedByAuthorizedUpdater() public {
        vm.prank(borrower);
        passport.registerPassport();

        vm.prank(attacker);
        vm.expectRevert(CreditRegistry.NotAuthorizedUpdater.selector);
        passport.updateProfile(borrower, 750, 2);

        vm.prank(address(this));
        passport.setCreditUpdater(updater, true);

        vm.warp(100);
        vm.prank(updater);
        passport.updateProfile(borrower, 750, 2);

        CreditRegistry.CreditProfile memory profile = passport.profiles(borrower);
        assertEq(profile.score, 750);
        assertEq(profile.riskTier, 2);
        assertEq(profile.lastUpdated, 100);
        assertTrue(profile.registered);
    }

    function testInvalidProfileValuesAndAddressesRevert() public {
        vm.prank(borrower);
        passport.registerPassport();

        passport.setCreditUpdater(updater, true);

        vm.startPrank(updater);
        vm.expectRevert(CreditRegistry.InvalidScore.selector);
        passport.updateProfile(borrower, 1_001, 1);

        vm.expectRevert(CreditRegistry.InvalidRiskTier.selector);
        passport.updateProfile(borrower, 500, 0);

        vm.expectRevert(CreditRegistry.InvalidRiskTier.selector);
        passport.updateProfile(borrower, 500, 4);

        vm.expectRevert(CreditRegistry.InvalidAddress.selector);
        passport.updateProfile(address(0), 500, 1);

        vm.expectRevert(CreditRegistry.NotRegistered.selector);
        passport.updateProfile(attacker, 500, 1);
        vm.stopPrank();
    }

    function testOwnerControlsUpdaterAuthorization() public {
        vm.prank(borrower);
        passport.registerPassport();

        vm.prank(attacker);
        vm.expectRevert();
        passport.setCreditUpdater(updater, true);

        passport.setCreditUpdater(updater, true);
        assertTrue(passport.authorizedUpdaters(updater));

        vm.prank(updater);
        passport.updateProfile(borrower, 100, 1);

        passport.setCreditUpdater(updater, false);
        assertFalse(passport.authorizedUpdaters(updater));

        vm.prank(updater);
        vm.expectRevert(CreditRegistry.NotAuthorizedUpdater.selector);
        passport.updateProfile(borrower, 200, 2);
    }

    function testUpdaterAuthorizationRejectsZeroAddress() public {
        vm.expectRevert(CreditRegistry.InvalidAddress.selector);
        passport.setCreditUpdater(address(0), true);
    }

    function testConstructorRejectsZeroOwner() public {
        vm.expectRevert();
        new CreditPassport(address(0));
    }
}
