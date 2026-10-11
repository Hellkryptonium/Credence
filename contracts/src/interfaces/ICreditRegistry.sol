// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICreditRegistry
/// @notice Interface for passport registration and authorized profile updates.
interface ICreditRegistry {
    struct CreditProfile {
        uint16 score;
        uint8 riskTier;
        uint256 lastUpdated;
        bool registered;
    }

    function registerPassport() external;

    function updateProfile(address wallet, uint16 score, uint8 riskTier) external;

    function setCreditUpdater(address updater, bool authorized) external;

    function isRegistered(address wallet) external view returns (bool);

    function profiles(address wallet) external view returns (CreditProfile memory);

    function authorizedUpdaters(address updater) external view returns (bool);
}
