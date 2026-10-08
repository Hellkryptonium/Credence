# ADR-0001: Initial Credence Architecture

## Status

Accepted

## Decision

Credence will use a monorepo containing:

- Next.js frontend
- Node.js API
- Solidity/Foundry contracts
- blockchain indexing layer
- shared TypeScript packages
- PostgreSQL application/indexing storage

Critical financial state will be enforced onchain.

Offchain infrastructure will provide indexing, aggregation, APIs, caching and analytics.

## Reason

The protocol must remain verifiable and must not make the backend the ultimate authority over financial state.