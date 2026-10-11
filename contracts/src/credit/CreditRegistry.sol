// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICreditRegistry} from "../interfaces/ICreditRegistry.sol";

/// @title CreditRegistry
/// @notice Stores self-registered credit passports and controls authorized profile updaters.
contract CreditRegistry is ICreditRegistry, Ownable {
    uint16 public constant MAX_SCORE = 1_000;
    uint8 public constant MIN_RISK_TIER = 1;
    uint8 public constant MAX_RISK_TIER = 3;

    mapping(address wallet => CreditProfile profile) private _profiles;
    mapping(address updater => bool authorized) public override authorizedUpdaters;

    error InvalidAddress();
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidScore();
    error InvalidRiskTier();
    error NotAuthorizedUpdater();

    event PassportRegistered(address indexed wallet, uint256 timestamp);
    event ProfileUpdated(address indexed wallet, uint16 score, uint8 riskTier, uint256 timestamp);
    event CreditUpdaterAuthorizationChanged(address indexed updater, bool authorized);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Registers a non-transferable passport for the calling wallet.
    function registerPassport() external virtual override {
        if (_profiles[msg.sender].registered) revert AlreadyRegistered();
        _profiles[msg.sender] = CreditProfile({score: 0, riskTier: 0, lastUpdated: block.timestamp, registered: true});
        emit PassportRegistered(msg.sender, block.timestamp);
    }

    /// @notice Updates a registered wallet's manually supplied credit profile.
    function updateProfile(address wallet, uint16 score, uint8 riskTier) external virtual override {
        if (!authorizedUpdaters[msg.sender]) revert NotAuthorizedUpdater();
        if (wallet == address(0)) revert InvalidAddress();
        if (!_profiles[wallet].registered) revert NotRegistered();
        if (score > MAX_SCORE) revert InvalidScore();
        if (riskTier < MIN_RISK_TIER || riskTier > MAX_RISK_TIER) revert InvalidRiskTier();

        _profiles[wallet].score = score;
        _profiles[wallet].riskTier = riskTier;
        _profiles[wallet].lastUpdated = block.timestamp;
        emit ProfileUpdated(wallet, score, riskTier, block.timestamp);
    }

    /// @notice Grants or revokes permission to manually update credit profiles.
    function setCreditUpdater(address updater, bool authorized) external override onlyOwner {
        if (updater == address(0)) revert InvalidAddress();
        authorizedUpdaters[updater] = authorized;
        emit CreditUpdaterAuthorizationChanged(updater, authorized);
    }

    /// @notice Returns whether a wallet has registered its passport.
    function isRegistered(address wallet) external view override returns (bool) {
        return _profiles[wallet].registered;
    }

    /// @notice Returns the complete stored profile for a wallet.
    function profiles(address wallet) external view override returns (CreditProfile memory) {
        return _profiles[wallet];
    }
}
