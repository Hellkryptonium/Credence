import assert from "node:assert/strict";
import test from "node:test";
import { buildUnsignedProfileUpdate } from "./profileUpdate.js";
import { RpcEvidenceCollector } from "./rpcEvidence.js";
import { calculateAssessment } from "./scoring.js";
import type { RawWalletEvidence } from "./schema.js";

const wallet = "0x0000000000000000000000000000000000000001";
const registry = "0x0000000000000000000000000000000000000002";

function evidence(transactionCount: bigint, nativeBalanceWei = 0n): RawWalletEvidence {
  return {
    schemaVersion: 1,
    network: {
      chainId: 11_155_111,
      blockNumber: 100n,
    },
    wallet,
    transactionCount,
    nativeBalanceWei,
    collectedAt: "2026-10-11T00:00:00.000Z",
  };
}

test("scoring is reproducible and bounded at the score maximum", () => {
  const first = calculateAssessment(evidence(2_000n, 1n));
  const second = calculateAssessment(evidence(2_000n, 1n));

  assert.deepEqual(first, second);
  assert.equal(first.score, 1_000);
  assert.equal(first.riskTier, 3);
});

test("score boundaries map deterministically to risk tiers", () => {
  assert.equal(calculateAssessment(evidence(0n)).score, 0);
  assert.equal(calculateAssessment(evidence(0n)).riskTier, 1);
  assert.equal(calculateAssessment(evidence(399n, 1n)).score, 499);
  assert.equal(calculateAssessment(evidence(399n, 1n)).riskTier, 2);
  assert.equal(calculateAssessment(evidence(600n, 1n)).score, 700);
  assert.equal(calculateAssessment(evidence(600n, 1n)).riskTier, 3);
});

test("malformed evidence is rejected before scoring", () => {
  assert.throws(
    () => calculateAssessment({...evidence(1n), schemaVersion: 2 as 1}),
    /Unsupported evidence schema version/,
  );
  assert.throws(() => calculateAssessment({...evidence(1n), wallet: "0x123"}), /Invalid evidence wallet address/);
  assert.throws(() => calculateAssessment({...evidence(1n), transactionCount: -1n}), /cannot be negative/);
});

test("RPC collector rejects missing and malformed data", async () => {
  const missingResult = new RpcEvidenceCollector({
    rpcUrl: "https://rpc.example",
    chainId: 1,
    fetchFn: async () =>
      new Response(JSON.stringify({jsonrpc: "2.0", id: 1, result: undefined}), {
        status: 200,
        headers: {"content-type": "application/json"},
      }),
  });
  await assert.rejects(() => missingResult.collect(wallet), /RPC response was invalid/);

  const malformedResult = new RpcEvidenceCollector({
    rpcUrl: "https://rpc.example",
    chainId: 1,
    fetchFn: async () =>
      new Response(JSON.stringify({jsonrpc: "2.0", id: 1, result: "not-hex"}), {
        status: 200,
        headers: {"content-type": "application/json"},
      }),
  });
  await assert.rejects(() => malformedResult.collect(wallet), /malformed block number/);
});

test("RPC collector requires HTTPS outside loopback and bounds timeouts", () => {
  assert.throws(
    () => new RpcEvidenceCollector({rpcUrl: "http://rpc.example", chainId: 1}),
    /HTTPS outside loopback/,
  );
  assert.throws(
    () => new RpcEvidenceCollector({rpcUrl: "https://rpc.example", chainId: 1, timeoutMs: 30_001}),
    /between 1ms and 30000ms/,
  );
  assert.doesNotThrow(() => new RpcEvidenceCollector({rpcUrl: "http://127.0.0.1:8545", chainId: 31_337}));
});

test("RPC evidence uses one explicit block for all state reads", async () => {
  const calls: Array<{method: string; params: unknown[]}> = [];
  const collector = new RpcEvidenceCollector({
    rpcUrl: "https://rpc.example",
    chainId: 1,
    fetchFn: async (_input, init) => {
      const request = JSON.parse(String(init?.body)) as {method: string; params: unknown[]};
      calls.push(request);
      const result =
        request.method === "eth_blockNumber"
          ? "0x64"
          : request.method === "eth_getTransactionCount"
            ? "0x02"
            : "0x01";
      return new Response(JSON.stringify({jsonrpc: "2.0", id: 1, result}), {status: 200});
    },
  });

  await collector.collect(wallet);
  assert.deepEqual(calls, [
    {jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []},
    {jsonrpc: "2.0", id: 1, method: "eth_getTransactionCount", params: [wallet, "0x64"]},
    {jsonrpc: "2.0", id: 1, method: "eth_getBalance", params: [wallet, "0x64"]},
  ]);
});

test("RPC collection times out bounded requests", async () => {
  const collector = new RpcEvidenceCollector({
    rpcUrl: "https://rpc.example",
    chainId: 1,
    timeoutMs: 1,
    fetchFn: async (_input, init) =>
      await new Promise((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => reject(new Error("aborted")));
      }),
  });

  await assert.rejects(() => collector.collect(wallet), /RPC request failed/);
});

test("profile update output is unsigned and contains no credential material", () => {
  const update = buildUnsignedProfileUpdate(registry, calculateAssessment(evidence(10n, 1n)));

  assert.equal(update.contractAddress, registry);
  assert.equal(update.wallet, wallet);
  assert.equal(update.evidenceSchemaVersion, 1);
  assert.equal(update.sourceBlock, "100");
  assert.equal("privateKey" in update, false);
  assert.equal("signature" in update, false);
});

test("unsigned profile update rejects invalid registry addresses", () => {
  assert.throws(
    () => buildUnsignedProfileUpdate("not-an-address", calculateAssessment(evidence(1n))),
    /Invalid credit registry address/,
  );
});
