// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CreditRegistry} from "./CreditRegistry.sol";

/// @title CreditPassport
/// @notice Non-transferable credit passport backed by a self-registered profile.
contract CreditPassport is CreditRegistry {
    constructor(address initialOwner) CreditRegistry(initialOwner) {}
}
