// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICreditRegistry} from "../interfaces/ICreditRegistry.sol";
import {IRiskEngine} from "../interfaces/IRiskEngine.sol";

/// @title RiskEngine
/// @notice Resolves deterministic, owner-configurable borrowing terms from credit profiles.
contract RiskEngine is IRiskEngine, Ownable {
    uint8 public constant MIN_RISK_TIER = 1;
    uint8 public constant MAX_RISK_TIER = 3;
    uint16 public constant MAX_SCORE = 1_000;
    uint16 public constant MAX_LTV_BPS = 5_000;

    /// @notice Conservative tier: 25% LTV and a 100-token cumulative debt cap.
    uint8 public constant CONSERVATIVE_TIER = 1;
    /// @notice Standard tier: 40% LTV and a 500-token cumulative debt cap.
    uint8 public constant STANDARD_TIER = 2;
    /// @notice Established tier: 50% LTV and a 1,000-token cumulative debt cap.
    uint8 public constant ESTABLISHED_TIER = 3;

    struct RiskTerms {
        uint16 minimumScore;
        uint16 maxLtvBps;
        uint256 maxBorrowAmount;
    }

    ICreditRegistry public immutable registry;
    mapping(uint8 tier => RiskTerms terms) public riskTerms;

    error InvalidAddress();
    error InvalidRiskTier();
    error InvalidScore();
    error InvalidLtv();
    error InvalidBorrowLimit();
    error NotRegistered();
    error ProfileNotEligible();

    event RiskTermsUpdated(uint8 indexed riskTier, uint16 minimumScore, uint16 maxLtvBps, uint256 maxBorrowAmount);

    constructor(ICreditRegistry registry_, address initialOwner) Ownable(initialOwner) {
        if (address(registry_) == address(0) || initialOwner == address(0)) revert InvalidAddress();
        registry = registry_;
        _setRiskTerms(CONSERVATIVE_TIER, 0, 2_500, 100 ether);
        _setRiskTerms(STANDARD_TIER, 400, 4_000, 500 ether);
        _setRiskTerms(ESTABLISHED_TIER, 700, 5_000, 1_000 ether);
    }

    /// @notice Updates the deterministic terms for one risk tier.
    function setRiskTerms(uint8 riskTier, uint16 minimumScore, uint16 maxLtvBps, uint256 maxBorrowAmount)
        external
        onlyOwner
    {
        _setRiskTerms(riskTier, minimumScore, maxLtvBps, maxBorrowAmount);
    }

    /// @notice Returns terms after validating registration, score, tier, and tier eligibility.
    function getBorrowingTerms(address borrower)
        external
        view
        override
        returns (uint16 maxLtvBps, uint256 maxBorrowAmount)
    {
        if (borrower == address(0)) revert InvalidAddress();
        ICreditRegistry.CreditProfile memory profile = registry.profiles(borrower);
        if (!profile.registered) revert NotRegistered();
        if (profile.score > MAX_SCORE) revert InvalidScore();
        if (profile.riskTier < MIN_RISK_TIER || profile.riskTier > MAX_RISK_TIER) revert InvalidRiskTier();

        RiskTerms memory terms = riskTerms[profile.riskTier];
        if (profile.score < terms.minimumScore) revert ProfileNotEligible();
        return (terms.maxLtvBps, terms.maxBorrowAmount);
    }

    function _setRiskTerms(uint8 riskTier, uint16 minimumScore, uint16 maxLtvBps, uint256 maxBorrowAmount) internal {
        if (riskTier < MIN_RISK_TIER || riskTier > MAX_RISK_TIER) revert InvalidRiskTier();
        if (minimumScore > MAX_SCORE) revert InvalidScore();
        if (maxLtvBps == 0 || maxLtvBps > MAX_LTV_BPS) revert InvalidLtv();
        if (maxBorrowAmount == 0) revert InvalidBorrowLimit();
        riskTerms[riskTier] = RiskTerms(minimumScore, maxLtvBps, maxBorrowAmount);
        emit RiskTermsUpdated(riskTier, minimumScore, maxLtvBps, maxBorrowAmount);
    }
}
