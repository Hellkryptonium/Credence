# Onchain Credit Protocol

> **Working name:** Credence
> **Core thesis:** *Turn verifiable onchain financial behavior into programmable borrowing power.*

A blockchain-native credit and lending protocol that analyzes a wallet's observable financial behavior, produces a transparent onchain credit profile, and uses that profile to determine borrowing terms such as collateral requirements, borrowing limits, and interest rates.

The project is being designed for the **Hack in Hills — Onchain Finance & Trading** track. The goal is not to build a generic lending dashboard. The goal is to demonstrate a financial mechanism that is meaningfully enabled by blockchain-native settlement, transparent smart-contract rules, and composable onchain reputation.

---

# 1. Product Vision

Traditional DeFi lending typically relies heavily on collateral.

A user may have years of responsible activity across protocols, successful repayments, and no liquidation history, while another wallet may be brand new. Yet a collateral-only system has little or no way to use that behavioral information to offer materially different terms.

Our protocol introduces a **credit layer** between wallet history and lending.

```text
Wallet
   │
   ▼
Observable Onchain Activity
   │
   ▼
Credit Features
   │
   ▼
Transparent Credit Engine
   │
   ▼
Credit Profile / Passport
   │
   ▼
Risk Engine
   │
   ├── Borrowing Limit
   ├── LTV
   ├── Interest Rate
   └── Eligibility
   │
   ▼
Onchain Lending
   │
   ├── Collateral
   ├── Borrow
   ├── Repay
   └── Liquidate
   │
   ▼
New Financial History
   │
   └──────────────► Credit Profile updates
```

The important feedback loop is:

> **Financial behavior → credit → better/worse terms → new financial behavior → updated credit.**

---

# 2. What We Are Building

## Core product

A user connects an EVM-compatible wallet such as MetaMask.

The application:

1. reads the wallet's public address;
2. retrieves relevant historical blockchain activity through an indexing layer;
3. converts raw activity into normalized credit features;
4. calculates a transparent protocol credit score;
5. assigns a risk tier;
6. determines borrowing terms;
7. lets the user borrow from an onchain liquidity pool;
8. records repayment/default/liquidation events onchain;
9. updates the user's credit profile.

## Example

A wallet with:

- long history;
- successful borrowing/repayment;
- low liquidation frequency;
- healthy collateral management;

could receive better protocol terms than a brand-new or historically risky wallet.

This is a **protocol-defined onchain risk score**, not a CIBIL, FICO, bank credit score, or legally recognized credit rating.

---

# 3. Why Blockchain Is Essential

This project must not become:

```text
Frontend
   ↓
Backend
   ↓
Database
   ↓
"Trust us, this user has score 817"
```

Instead:

```text
Blockchain activity
        ↓
Indexed evidence
        ↓
Deterministic credit rules
        ↓
Verifiable credit state
        ↓
Smart-contract risk checks
        ↓
Onchain loan
```

Critical financial state belongs onchain:

- loan creation;
- collateral;
- borrowing;
- repayment;
- interest accounting;
- liquidation;
- credit-related protocol state;
- emitted financial events;
- risk parameters where practical.

Offchain infrastructure is used for:

- indexing;
- data aggregation;
- caching;
- analytics;
- frontend;
- APIs;
- computationally expensive preprocessing.

The backend is an **observer/processor/indexing component**, not the ultimate authority over whether a loan contract may execute.

---

# 4. Design Principles

## 4.1 Verifiable

A user should be able to understand why a credit result was produced and inspect relevant blockchain evidence.

## 4.2 Deterministic

Given the same approved data and protocol parameters, the score should be reproducible.

## 4.3 Composable

The credit layer should eventually be consumable by other onchain applications.

## 4.4 Portable

A user's reputation should not be permanently trapped inside one frontend.

## 4.5 Manipulation-resistant

Simple transaction spam, self-transfers, wash activity, or wallet splitting should not trivially produce an artificially high score.

## 4.6 Privacy-aware

The advanced roadmap should support proving a credit condition without exposing unnecessary underlying financial history.

## 4.7 Security-first

This is a financial protocol. Smart-contract correctness matters more than feature count.

---

# 5. Recommended Tech Stack

## Blockchain

**Primary implementation target:** EVM-compatible testnet.

Candidate:
- Base Sepolia if it is the current supported/suitable environment for the hackathon.
- Keep chain-specific configuration isolated so the deployment target can change without redesigning the protocol.

Do not hard-code the architecture around one testnet.

## Smart Contracts

- Solidity
- Foundry
- OpenZeppelin Contracts

## Frontend

- Next.js
- TypeScript
- Tailwind CSS
- shadcn/ui
- wagmi
- viem
- RainbowKit

## Wallet

- MetaMask
- other wallets through WalletConnect-compatible providers if useful

## Blockchain Data / Indexing

Choose **one** indexing stack initially:

- Envio
- Goldsky
- The Graph

Do **not** integrate all three unless there is a concrete engineering reason.

## Backend

- Node.js
- TypeScript
- Fastify or Hono
- PostgreSQL
- Drizzle ORM

## Oracle

- Chainlink price feeds where supported and appropriate

## Testing

- Foundry tests for contracts
- Vitest for TypeScript
- integration tests
- end-to-end demo tests

## Deployment

- Vercel for frontend
- Railway / Render / Fly.io for API
- testnet for contract deployment

---

# 6. High-Level Architecture

```text
                                  USER
                                   │
                                   ▼
                              MetaMask
                                   │
                                   ▼
                        RainbowKit + Wagmi
                                   │
                                   ▼
                              Next.js
                                   │
                     ┌─────────────┴─────────────┐
                     │                           │
                     ▼                           ▼
              Read Credit Profile         Write Transactions
                     │                           │
                     ▼                           ▼
                Credit API                Smart Contracts
                     │               ┌───────────┼───────────┐
                     │               │           │           │
                     │               ▼           ▼           ▼
                     │          CreditRegistry  LendingPool RiskEngine
                     │                               │
                     │                               ▼
                     │                          LoanManager
                     │                               │
                     │                               ▼
                     │                             Oracle
                     │
                     ▼
                Indexed Data
                     │
                     ▼
               Credit Engine
                     │
                     ▼
              PostgreSQL / Cache

                         BLOCKCHAIN
```

---

# 7. Repository Structure

Recommended monorepo:

```text
onchain-credit/
│
├── apps/
│   ├── web/
│   │   ├── app/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── lib/
│   │   └── ...
│   │
│   └── api/
│       ├── src/
│       │   ├── routes/
│       │   ├── services/
│       │   ├── repositories/
│       │   └── ...
│       └── ...
│
├── packages/
│   ├── types/
│   ├── credit-engine/
│   ├── config/
│   └── ui/
│
├── contracts/
│   ├── src/
│   │   ├── CreditRegistry.sol
│   │   ├── CreditScoring.sol
│   │   ├── RiskEngine.sol
│   │   ├── LendingPool.sol
│   │   ├── LoanManager.sol
│   │   └── interfaces/
│   │
│   ├── test/
│   │   ├── CreditRegistry.t.sol
│   │   ├── CreditScoring.t.sol
│   │   ├── RiskEngine.t.sol
│   │   ├── LendingPool.t.sol
│   │   └── LoanManager.t.sol
│   │
│   ├── script/
│   │   └── Deploy.s.sol
│   │
│   └── foundry.toml
│
├── indexer/
│   ├── config/
│   ├── handlers/
│   ├── schema/
│   └── ...
│
├── scripts/
│   ├── demo/
│   │   ├── create-wallets.ts
│   │   ├── fund-wallets.ts
│   │   ├── good-borrower.ts
│   │   ├── new-wallet.ts
│   │   └── risky-borrower.ts
│   │
│   └── deployment/
│
├── docs/
│   ├── protocol.md
│   ├── credit-model.md
│   ├── risk-model.md
│   ├── security.md
│   └── demo.md
│
├── .env.example
├── docker-compose.yml
├── package.json
├── pnpm-workspace.yaml
└── README.md
```

---

# 8. Core Smart Contracts

The protocol should initially use a small number of focused contracts.

## 8.1 `CreditRegistry.sol`

Purpose:

Maintain the protocol-recognized credit state for an address.

Possible state:

```solidity
struct CreditProfile {
    uint256 score;
    uint8 tier;
    uint256 successfulRepayments;
    uint256 liquidations;
    uint256 creditAge;
    uint256 lastUpdated;
}
```

The design must distinguish between:

- raw observations;
- calculated features;
- protocol-approved credit state.

Avoid storing unnecessary historical data directly onchain if it is expensive. Large histories should remain queryable through events/indexing while important aggregate state remains onchain.

---

# 9. `CreditScoring.sol`

Purpose:

Calculate the protocol's credit score from approved features.

Example feature set:

```text
Repayment behavior          30%
Liquidation history         20%
Wallet age                  15%
Collateral management       15%
DeFi experience             10%
Capital/activity consistency 10%
```

These percentages are **initial protocol design values**, not financial truth.

The important requirement is that the scoring logic is:

- documented;
- reproducible;
- bounded;
- explainable;
- resistant to trivial manipulation.

Potential output:

```text
800–1000 → AAA
700–799  → AA
600–699  → A
500–599  → B
0–499    → C / Limited
```

New wallets should receive an explicit:

```text
NEW / INSUFFICIENT HISTORY
```

state rather than a fabricated high score.

---

# 10. `RiskEngine.sol`

Converts credit/risk information into lending parameters.

Possible parameters:

```text
Maximum LTV
Maximum borrow amount
Interest rate
Collateral requirement
Minimum health factor
Eligibility
```

Example:

```text
AAA:
  higher LTV
  lower risk premium

AA:
  moderately higher LTV
  moderately lower risk premium

A:
  standard secured terms

B:
  lower LTV
  higher risk premium

C:
  heavily restricted terms

NEW:
  highly collateralized starter position
```

Do not use arbitrary hardcoded values throughout the code.

Use centralized, governed parameters so the protocol can evolve.

---

# 11. `LendingPool.sol`

Purpose:

Manage lender liquidity.

Core functions:

```solidity
deposit()
withdraw()
borrow()
repay()
```

Pool accounting should track:

```text
Total liquidity
Available liquidity
Utilized liquidity
Outstanding debt
Interest
```

---

# 12. `LoanManager.sol`

Tracks individual loans.

Example:

```text
Loan
├── borrower
├── asset
├── collateral asset
├── principal
├── interest rate
├── start timestamp
├── accrued interest
├── collateral amount
├── health factor
└── status
```

Loan states:

```text
ACTIVE
REPAID
LIQUIDATED
DEFAULTED
```

---

# 13. Oracle

For collateralized lending we need a reliable price source.

Example:

```text
ETH/USD
```

The lending system needs a current valuation for:

```text
collateral value
debt value
LTV
health factor
liquidation threshold
```

Use Chainlink or another approved oracle compatible with the deployment chain.

Do not write a fake price oracle for the final financial flow unless it is explicitly marked as a test/demo component.

For local tests, mocks are fine.

---

# 14. Credit Data Pipeline

The data pipeline is one of the hardest parts.

Raw blockchain activity is not automatically a credit score.

The pipeline should be:

```text
Blockchain
    ↓
Indexer
    ↓
Protocol / transaction events
    ↓
Normalized Activity
    ↓
Feature Extraction
    ↓
Credit Engine
    ↓
Credit Profile
    ↓
Risk Engine
```

---

# 15. What We Should Analyze

Do not attempt to analyze every DeFi protocol in V1.

Start with a defined universe.

Possible first sources:

```text
Our own lending protocol
Selected lending protocol(s)
Selected DEX activity
Stablecoin activity
Wallet age / transaction history
```

Useful features:

### Wallet age

How long the address has been active.

### Repayment record

Successful repayments recognized by supported lending protocols.

### Liquidation record

Historical liquidation events.

### Collateral discipline

How consistently the user maintained healthy collateralization.

### DeFi breadth

Reasonable evidence of genuine protocol usage rather than one-off transfers.

### Capital consistency

Longitudinal behavior rather than raw transaction count.

---

# 16. What We Should NOT Reward Too Heavily

Avoid naive features such as:

```text
transaction count
number of token transfers
raw gas spent
number of self-transfers
```

Otherwise a user could game the system by:

```text
A → B
B → A
A → B
B → A
...
```

and manufacture fake activity.

The scoring model must reward meaningful financial behavior, not noise.

---

# 17. Anti-Sybil / Anti-Gaming Design

Potential attacks:

### Wallet splitting

One person controls 50 wallets.

### Wash transfers

Money is moved between controlled addresses.

### Transaction spam

An attacker creates thousands of transactions.

### Circular borrowing

A user creates artificial repay/borrow loops.

### Sybil reputation farming

Multiple addresses interact with each other to manufacture history.

### Capital injection

A large external transfer temporarily makes a wallet appear healthier.

Mitigation should include:

- weighted rather than raw transaction counts;
- protocol-specific recognized events;
- time-weighted history;
- minimum history duration;
- suspicious relationship detection;
- diminishing returns;
- caps per feature;
- explicit treatment of self/circular activity where detectable;
- conservative treatment of fresh wallets.

---

# 18. Credit Passport

Once core lending works, introduce:

```text
Credit Passport
```

Example:

```text
CREDIT PASSPORT

Wallet:
0xABC...123

Tier:
AA

Score:
817

Successful repayments:
37

Liquidations:
1

Credit age:
418 days

Last updated:
Block #...
```

The passport should expose only meaningful, composable state.

The goal is eventually:

```text
getCreditTier(address)
getCreditScore(address)
getBorrowingPower(address)
```

so another protocol can consume the result.

---

# 19. Portable Credit

Long-term architecture:

```text
                    Credit Passport
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
         Our Market     Protocol B    Protocol C
             │             │             │
          Lending        Lending       Other use
```

This turns the project into:

> **An onchain credit infrastructure layer**

rather than merely:

> **A lending application.**

---

# 20. Privacy / ZK Roadmap

Advanced feature:

Allow a user to prove:

```text
My credit score is above X
```

without necessarily revealing the full underlying history.

Conceptual flow:

```text
Financial history
       ↓
Credit computation
       ↓
ZK proof generation
       ↓
"score >= 750"
       ↓
Proof verification
       ↓
Lending protocol
```

Potential future tooling:

- Noir
- RISC Zero
- Circom / snarkjs
- other appropriate proving systems

Do not begin with ZK.

The priority is:

```text
real lending
    ↓
real credit
    ↓
portable credit
    ↓
privacy
```

---

# 21. Dynamic Interest Rate Model

The initial model can be simple.

The advanced model should be:

```text
Final APR =
Base Rate
+ Borrower Risk Premium
+ Pool Utilization Adjustment
+ Loan Duration Adjustment
+ Asset Risk Adjustment
```

Conceptually:

```text
                    Base Market Rate
                           │
                           +
                           ▼
                    Credit Premium
                           │
                           +
                           ▼
                  Pool Utilization
                           │
                           +
                           ▼
                    Loan Duration
                           │
                           +
                           ▼
                       Final APR
```

This should be deterministic and transparent.

---

# 22. Health Factor / Liquidation

Each loan should expose its risk state.

Example conceptual model:

```text
Health Factor > safe threshold
        ↓
        SAFE

Health Factor approaching threshold
        ↓
       WARNING

Health Factor below liquidation threshold
        ↓
   LIQUIDATABLE
```

Liquidation flow:

```text
Collateral price decreases
        ↓
Health factor decreases
        ↓
Liquidation threshold crossed
        ↓
Liquidator calls liquidation
        ↓
Debt is covered
        ↓
Collateral is seized/sold according to protocol
        ↓
Borrower credit history records event
```

The exact liquidation mechanics need to be specified carefully before implementation.

---

# 23. Liquidity Provider Flow

The other side of the market:

```text
Liquidity Provider
       ↓
Deposit USDC
       ↓
Lending Pool
       ↓
Borrowers
       ↓
Interest
       ↓
LP yield
```

LP dashboard:

```text
Supplied liquidity
Pool utilization
Outstanding borrows
Current yield
Risk distribution
Bad debt
```

A strong future feature is allowing LPs to understand borrower risk distribution.

---

# 24. Demo Wallet Strategy

We should not rely on the team's personal wallets having rich histories.

Create controlled testnet demo wallets.

## Wallet A — Good borrower

Simulate:

```text
borrow
repay
borrow
repay
borrow
repay
```

Result:

```text
strong repayment history
0 liquidations
high score
```

## Wallet B — New user

Fresh wallet:

```text
minimal activity
no lending history
```

Result:

```text
NEW / INSUFFICIENT HISTORY
high collateral requirement
small initial borrowing limit
```

## Wallet C — Risky user

Simulate a position that reaches liquidation.

Result:

```text
lower score
restricted terms
```

## Optional Wallet D — Real public wallet

Use a public mainnet address for **analysis only**.

Do not pretend we control it.

This lets the demo show:

```text
Analyze arbitrary public wallet
```

while the actual borrow/repay flow uses controlled testnet wallets.

---

# 25. Ideal Demo

The demo should take less than 3 minutes.

## Step 1 — Connect

```text
Connect MetaMask
```

## Step 2 — Analyze

Display:

```text
Credit Score: 817
Tier: AA
Borrowing Power: $4,850
APR: 8.2%
```

## Step 3 — Explain

Show:

```text
Why 817?

37 successful repayments
418-day wallet history
Healthy collateral behavior
1 historical liquidation
```

Every important evidence item should link to blockchain data.

## Step 4 — Borrow

Example testnet transaction:

```text
Borrow: 2,000 USDC
Collateral: required amount
LTV: protocol-calculated
APR: protocol-calculated
```

MetaMask signs the transaction.

## Step 5 — Repay

User repays.

## Step 6 — Reputation update

Show:

```text
817 → 832
```

with:

> Successful repayment added to protocol credit history.

## Step 7 — Compare

Switch to the risky wallet:

```text
Score: 412
Tier: C
```

Then show different borrowing terms.

## Step 8 — Advanced proof

If ZK is complete:

```text
Credit requirement:
score ≥ 750

Proof:
VALID
```

---

# 26. Frontend Pages

Recommended pages:

```text
/
├── Landing
│
├── /dashboard
│
├── /credit
│   └── Detailed credit profile
│
├── /borrow
│   └── Loan creation
│
├── /loans
│   └── Active / previous loans
│
├── /liquidity
│   └── LP dashboard
│
├── /passport
│   └── Credit Passport
│
└── /explorer
    └── Protocol events / evidence
```

---

# 27. Main Dashboard

Example:

```text
┌─────────────────────────────────────────────┐
│ [PROJECT]                      0x72A...91F  │
├─────────────────────────────────────────────┤
│                                             │
│ YOUR ONCHAIN CREDIT                         │
│                                             │
│                  817                        │
│                   AA                        │
│                                             │
│ Borrowing Power        $4,850               │
│ Current Exposure       $2,000               │
│                                             │
│ [ BORROW ]       [ CREDIT PASSPORT ]        │
│                                             │
├─────────────────────────────────────────────┤
│ CREDIT EVIDENCE                             │
│                                             │
│ ✓ 37 successful repayments                  │
│ ✓ 418 days active                           │
│ ✓ Healthy collateral history                │
│ ⚠ 1 historical liquidation                 │
├─────────────────────────────────────────────┤
│ ACTIVE LOANS                                │
│                                             │
│ $2,000 USDC   8.2% APR   Health 2.14       │
└─────────────────────────────────────────────┘
```

---

# 28. API Design

Example endpoints:

```text
GET /health

GET /wallet/:address/profile

GET /wallet/:address/features

GET /wallet/:address/evidence

GET /wallet/:address/loans

GET /wallet/:address/history

GET /market/pool

GET /market/parameters

GET /loans/:loanId
```

The API should not become the financial authority.

It provides read/analytics services while smart contracts enforce the actual financial state.

---

# 29. Example Response

`GET /wallet/0x.../profile`

```json
{
  "address": "0x...",
  "score": 817,
  "tier": "AA",
  "status": "VERIFIED",
  "borrowingPower": "4850",
  "recommendedLtv": 75,
  "estimatedRiskPremium": 0.021,
  "features": {
    "repayment": 94,
    "liquidation": 87,
    "walletAge": 91,
    "collateralManagement": 88
  }
}
```

The values above are illustrative.

The production implementation must derive values from actual indexed data.

---

# 30. Database

PostgreSQL is primarily for indexed/application data.

Example tables:

```text
wallets
wallet_features
credit_profiles
credit_snapshots
protocol_events
loans
repayments
liquidations
pool_snapshots
transactions
```

Important distinction:

```text
Blockchain
= source of truth for protocol state

PostgreSQL
= queryable representation / analytics
```

If the database disappears, the protocol should not lose the authoritative loan state.

---

# 31. Events

Contracts should emit clean events.

Example:

```solidity
event LoanCreated(
    uint256 indexed loanId,
    address indexed borrower,
    uint256 amount
);

event LoanRepaid(
    uint256 indexed loanId,
    address indexed borrower,
    uint256 amount
);

event LoanLiquidated(
    uint256 indexed loanId,
    address indexed borrower
);

event CreditProfileUpdated(
    address indexed borrower,
    uint256 score,
    uint8 tier
);
```

These events make indexing and demo verification much easier.

---

# 32. Security Requirements

Before calling the protocol "complete", test:

## Smart contract security

- reentrancy;
- access control;
- authorization;
- integer/precision issues;
- rounding;
- token approval edge cases;
- unexpected ERC-20 behavior;
- stale oracle prices;
- oracle failure;
- liquidation edge cases;
- insufficient liquidity;
- debt accounting;
- interest accounting;
- collateral accounting.

## Credit system security

- Sybil farming;
- transaction spam;
- circular activity;
- score manipulation;
- stale data;
- indexer inconsistency;
- replayed updates;
- unauthorized score updates.

## Operational security

- private keys only in secure environment;
- no secrets committed;
- deployer keys separated from user wallets;
- testnet-only demo funds;
- contract addresses versioned in deployment config.

---

# 33. Testing Strategy

Testing should be layered.

## Unit tests

Each contract independently.

## Integration tests

```text
deposit
→ collateral
→ borrow
→ interest
→ repay
→ collateral withdrawal
```

## Liquidation tests

```text
borrow
→ price drops
→ health factor drops
→ liquidation
→ debt settlement
```

## Credit tests

```text
good history
→ score increases

liquidation
→ score decreases

new wallet
→ insufficient-history state
```

## Manipulation tests

Attempt:

```text
transaction spam
circular transfers
wallet splitting
artificial volume
```

and verify the score is not trivially inflated.

---

# 34. Development Phases

## Phase 0 — Specification

Deliver:

```text
protocol.md
credit-model.md
risk-model.md
contracts.md
```

Define:

- scoring;
- lending;
- risk;
- liquidation;
- ownership/governance;
- supported assets.

---

## Phase 1 — Basic Lending

Implement:

```text
LendingPool
LoanManager
Collateral
Mock Oracle
```

Working flow:

```text
deposit → borrow → repay
```

---

## Phase 2 — Risk Engine

Add:

```text
credit tier
→ LTV
→ borrowing limit
→ risk premium
```

Initially use mocked credit states.

---

## Phase 3 — Real Wallet Analysis

Integrate one indexing platform.

Build:

```text
wallet
→ indexed activity
→ normalized features
```

---

## Phase 4 — Credit Engine

Implement real feature calculation.

Deliver:

```text
score
tier
explanation
evidence
```

---

## Phase 5 — Credit-Based Lending

Connect:

```text
credit score
→ risk engine
→ actual loan terms
```

At this point the core project exists.

---

## Phase 6 — Liquidation

Implement oracle + health factor + liquidation.

Ensure liquidation affects credit state.

---

## Phase 7 — Credit Passport

Expose portable credit state.

---

## Phase 8 — Dynamic Pricing

Add utilization and borrower-risk adjustments.

---

## Phase 9 — Advanced Privacy

Prototype ZK credit eligibility proof.

---

## Phase 10 — Security + Polish

Focus on:

- contract security;
- attack simulations;
- UX;
- transaction states;
- error handling;
- evidence links;
- analytics;
- demo reliability.

---

# 35. Definition of Done

The core protocol is considered complete only when a judge can perform this flow:

```text
1. Open application
2. Connect MetaMask
3. Analyze wallet
4. Receive a real protocol credit profile
5. Understand why the score exists
6. See personalized borrowing terms
7. Deposit collateral
8. Borrow testnet USDC
9. See loan recorded onchain
10. Repay
11. See collateral returned
12. See credit state updated
13. Analyze another wallet
14. Observe different risk terms
15. Verify transactions on a block explorer
```

The advanced version adds:

```text
16. Credit Passport
17. Portable credit verification
18. Dynamic pricing
19. Strong anti-gaming logic
20. ZK eligibility proof
```

---

# 36. Demo Environment

Use dedicated demo wallets.

Recommended:

```text
DEMO_GOOD
DEMO_NEW
DEMO_RISKY
DEMO_PUBLIC_ANALYSIS
```

Never store private keys in Git.

Use local `.env` files or a secure secret system.

Example:

```env
CHAIN_ID=
RPC_URL=
NEXT_PUBLIC_RPC_URL=

DEPLOYER_PRIVATE_KEY=

CREDIT_REGISTRY_ADDRESS=
CREDIT_SCORING_ADDRESS=
RISK_ENGINE_ADDRESS=
LENDING_POOL_ADDRESS=
LOAN_MANAGER_ADDRESS=

DATABASE_URL=

INDEXER_API_URL=
CHAINLINK_FEED_ADDRESS=
```

Commit only:

```text
.env.example
```

---

# 37. Demo Data Philosophy

Do not fake credit histories inside the UI.

The demo wallet histories should be generated through actual testnet transactions where possible.

For example:

```text
GOOD WALLET

Borrow
 ↓
Repay
 ↓
Borrow
 ↓
Repay
 ↓
Borrow
 ↓
Repay
```

Then the indexer discovers the events and the credit engine derives the profile.

This creates a genuine end-to-end demonstration.

---

# 38. Public Wallet Analysis

The application may also support:

```text
Analyze any wallet
```

The user enters:

```text
0x...
```

The application retrieves publicly observable information and produces an analysis.

Important:

- never claim to know private financial information;
- clearly label incomplete histories;
- clearly distinguish protocol score from traditional credit scores;
- do not imply that a public wallet owner is the person operating the frontend.

---

# 39. UX Principles

The product must feel like a financial application, not a blockchain explorer.

Use:

- dark premium interface;
- large credit score;
- clear risk tier;
- simple borrowing flow;
- transaction progress;
- explorer verification;
- evidence cards;
- clear warnings;
- minimal wallet jargon.

Every transaction should clearly display:

```text
WHAT
WHY
HOW MUCH
RISK
WHAT HAPPENS NEXT
```

---

# 40. Hackathon Presentation Strategy

The presentation should not dump the entire architecture on judges.

The narrative should be:

```text
Problem
   ↓
DeFi does not price financial reputation well
   ↓
Solution
   ↓
Onchain credit layer
   ↓
Mechanism
   ↓
Wallet → credit → risk → loan → repayment
   ↓
Technology
   ↓
Actual implementation
   ↓
Demo
   ↓
Future
```

Core one-line pitch:

> **[PROJECT_NAME] turns verifiable onchain financial behavior into programmable borrowing power.**

---

# 41. Presentation Demo Sequence

Use a controlled wallet so the demo is deterministic.

### Screen 1

```text
CONNECT WALLET
```

### Screen 2

```text
Analyzing onchain history...

Credit Score: 817
Tier: AA
Borrowing Power: $4,850
```

### Screen 3

```text
Why?

37 successful repayments
418 days of history
Healthy collateral management
1 liquidation
```

### Screen 4

```text
Borrow $2,000 USDC
```

### Screen 5

MetaMask confirmation.

### Screen 6

```text
Loan #42
$2,000
APR 8.2%
Health Factor 2.14
```

### Screen 7

Repay.

### Screen 8

```text
817 → 832

Successful repayment added.
```

### Screen 9

Switch to risky wallet:

```text
Score: 412
Tier: C
Restricted borrowing terms
```

The judges now understand the mechanism rather than merely seeing screenshots.

---

# 42. Important Product Limitations

The first version will have real limitations.

## Not all onchain activity is meaningful credit information.

A wallet can be active without being creditworthy.

## A wallet is not necessarily a unique human.

One person can operate many addresses.

## Public activity does not reveal private financial information.

The system only sees what the selected chain/protocols expose publicly.

## Credit scores are model outputs.

They are not objective universal measures of human reliability.

## Mainnet lending introduces real financial risk.

The hackathon prototype should operate on testnet unless a production deployment is specifically audited and approved.

These limitations should be acknowledged rather than hidden.

---

# 43. Future Architecture

Long-term:

```text
                    ONCHAIN CREDIT LAYER
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
       Credit Passport   Risk Engine      ZK Proof
              │              │              │
              └──────────────┼──────────────┘
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
        Lending          Borrowing         Other DeFi
        Markets           Markets          Applications
```

The strategic goal is:

> **Become the reputation/risk layer other onchain financial applications can use.**

---

# 44. Suggested Build Order During the Prototype Week

### Day 1

```text
Repository
Foundry setup
Contracts skeleton
Token mocks
Deployment scripts
```

### Day 2

```text
LendingPool
LoanManager
Collateral
Borrow
Repay
```

### Day 3

```text
RiskEngine
Health Factor
Oracle
Liquidation
```

### Day 4

```text
Indexer
Wallet activity
Credit feature extraction
Credit score
```

### Day 5

```text
Credit-based loan terms
Credit Registry
Credit updates
```

### Day 6

```text
Frontend
Wallet connection
Credit dashboard
Borrow flow
Repay flow
```

### Day 7

```text
Demo wallets
Security tests
Explorer links
Polish
Pitch recording
Failure recovery
```

The exact schedule can be adjusted once the hackathon's prototype constraints are confirmed.

---

# 45. Final Architecture Goal

```text
                                 USER
                                  │
                                  ▼
                         MetaMask / Wallet
                                  │
                                  ▼
                    RainbowKit + Wagmi + Viem
                                  │
                                  ▼
                              WEB APP
                                  │
                   ┌──────────────┴──────────────┐
                   │                             │
                   ▼                             ▼
            CREDIT DASHBOARD               TRANSACTIONS
                   │                             │
                   ▼                             ▼
             CREDIT API                    SMART CONTRACTS
                   │                   ┌─────────┼──────────┐
                   │                   │         │          │
                   │                   ▼         ▼          ▼
                   │               CREDIT    RISK       LENDING
                   │               REGISTRY   ENGINE      POOL
                   │                             │          │
                   │                             └────┬─────┘
                   │                                  ▼
                   │                              LOANS
                   │                                  │
                   │                               ORACLE
                   │
                   ▼
                 INDEXER
                   │
                   ▼
             BLOCKCHAIN DATA
                   │
                   ▼
             CREDIT ENGINE
                   │
                   ▼
            CREDIT FEATURES
```

---

# 46. Success Criteria

We should optimize for these outcomes:

### Technical

- real smart-contract financial flow;
- reproducible credit computation;
- indexed wallet history;
- robust risk checks;
- liquidation mechanism;
- comprehensive tests;
- clear separation of onchain/offchain components.

### Product

- obvious user value;
- excellent credit-profile UX;
- useful evidence;
- personalized terms;
- intuitive borrow/repay flow.

### Hackathon

The judges should be able to answer "yes" to:

```text
Is blockchain necessary?
        YES

Is the financial mechanism real?
        YES

Is there genuine innovation?
        YES

Can we understand it quickly?
        YES

Can we verify the claims?
        YES

Does it scale beyond this demo?
        YES
```

---

# 47. Non-Negotiable Rules

1. **Do not fake onchain state.**
2. **Do not call the protocol score a CIBIL/FICO score.**
3. **Do not depend on the backend for final loan authorization.**
4. **Do not integrate three indexers when one works.**
5. **Do not build ZK before basic lending works.**
6. **Do not sacrifice contract security for extra features.**
7. **Do not use huge transaction count as the main definition of creditworthiness.**
8. **Do not depend on personal wallets for the demo.**
9. **Do not claim unsupported financial facts about public wallets.**
10. **Every important demo claim should be reproducible or verifiable.**

---

# 48. Immediate Next Tasks

Before writing substantial application code:

```text
[ ] Final project name
[ ] Final chain/testnet
[ ] Final supported assets
[ ] Credit feature specification
[ ] Credit scoring formula
[ ] Risk/LTV model
[ ] Liquidation model
[ ] Contract interfaces
[ ] Indexer selection
[ ] Repository initialization
[ ] Demo wallet strategy
```

Once these are locked, implementation should start with the smart-contract core and a testnet deployment.

---

## One-sentence product definition

> **[PROJECT_NAME] is an onchain credit layer that converts verifiable financial behavior into transparent, programmable, and eventually portable borrowing power.**