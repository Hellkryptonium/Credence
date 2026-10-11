// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {LoanManager} from "../src/lending/LoanManager.sol";

/// @title Deploy
/// @notice Deploys the Phase 1 protocol around an externally supplied ERC20 asset.
contract Deploy is Script {
    function run() external returns (LendingPool pool, LoanManager manager) {
        IERC20 asset = IERC20(vm.envAddress("ASSET"));
        vm.startBroadcast();
        pool = new LendingPool(asset, msg.sender);
        manager = new LoanManager(pool, asset);
        pool.setLoanManager(address(manager));
        vm.stopBroadcast();
    }
}
