// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "../src/lending/LendingPool.sol";
import {LoanManager} from "../src/lending/LoanManager.sol";
import {CreditPassport} from "../src/credit/CreditPassport.sol";
import {RiskEngine} from "../src/risk/RiskEngine.sol";

/// @title Deploy
/// @notice Deploys the Phase 1 lending and Phase 3 risk components around an external ERC20 asset.
contract Deploy is Script {
    function run()
        external
        returns (CreditPassport passport, RiskEngine riskEngine, LendingPool pool, LoanManager manager)
    {
        IERC20 asset = IERC20(vm.envAddress("ASSET"));
        vm.startBroadcast();
        passport = new CreditPassport(msg.sender);
        riskEngine = new RiskEngine(passport, msg.sender);
        pool = new LendingPool(asset, msg.sender);
        manager = new LoanManager(pool, asset, riskEngine);
        pool.setLoanManager(address(manager));
        vm.stopBroadcast();
    }
}
