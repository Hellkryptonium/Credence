import {
  EVIDENCE_SCHEMA_VERSION,
  type RawWalletEvidence,
  validateWalletEvidence,
} from "./schema.js";
import { isAddress } from "./validation.js";

type RpcResponse<T> = {
  jsonrpc: "2.0";
  id: number;
  result?: T;
  error?: { code: number; message: string };
};

export type EvidenceCollectorConfig = {
  rpcUrl: string;
  chainId: number;
  fetchFn?: typeof fetch;
  timeoutMs?: number;
};

export class RpcEvidenceCollector {
  private readonly fetchFn: typeof fetch;

  public constructor(private readonly config: EvidenceCollectorConfig) {
    const rpcUrl = new URL(config.rpcUrl);
    if (rpcUrl.protocol !== "https:" && !isLoopbackHost(rpcUrl.hostname)) {
      throw new Error("RPC URL must use HTTPS outside loopback development");
    }
    if (!Number.isSafeInteger(config.chainId) || config.chainId <= 0) {
      throw new Error("Configured chain ID must be a positive safe integer");
    }
    if (
      config.timeoutMs !== undefined &&
      (!Number.isSafeInteger(config.timeoutMs) || config.timeoutMs <= 0 || config.timeoutMs > 30_000)
    ) {
      throw new Error("RPC timeout must be between 1ms and 30000ms");
    }
    this.fetchFn = config.fetchFn ?? fetch;
  }

  public async collect(wallet: string): Promise<RawWalletEvidence> {
    if (!isAddress(wallet)) {
      throw new Error("Invalid wallet address");
    }

    const blockHex = await this.request<string>("eth_blockNumber", []);
    parseQuantity(blockHex, "block number");
    const [transactionCountHex, balanceHex] = await Promise.all([
      this.request<string>("eth_getTransactionCount", [wallet, blockHex]),
      this.request<string>("eth_getBalance", [wallet, blockHex]),
    ]);

    const evidence: RawWalletEvidence = {
      schemaVersion: EVIDENCE_SCHEMA_VERSION,
      network: {
        chainId: this.config.chainId,
        blockNumber: parseQuantity(blockHex, "block number"),
      },
      wallet: wallet.toLowerCase(),
      transactionCount: parseQuantity(transactionCountHex, "transaction count"),
      nativeBalanceWei: parseQuantity(balanceHex, "native balance"),
      collectedAt: new Date().toISOString(),
    };
    validateWalletEvidence(evidence);
    return evidence;
  }

  private async request<T>(method: string, params: unknown[]): Promise<T> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.config.timeoutMs ?? 5_000);
    try {
      const response = await this.fetchFn(this.config.rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error("RPC request failed");
      }
      let body: unknown;
      try {
        body = await response.json();
      } catch {
        throw new Error("RPC response was not valid JSON");
      }
      if (!isRpcResponse<T>(body) || body.error || body.result === undefined) {
        throw new Error("RPC response was invalid");
      }
      return body.result;
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("RPC ")) {
        throw error;
      }
      throw new Error("RPC request failed");
    } finally {
      clearTimeout(timeout);
    }
  }
}

function parseQuantity(value: string, label: string): bigint {
  if (!/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new Error(`RPC returned malformed ${label}`);
  }
  return BigInt(value);
}

function isLoopbackHost(hostname: string): boolean {
  return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1";
}

function isRpcResponse<T>(value: unknown): value is RpcResponse<T> {
  if (typeof value !== "object" || value === null) return false;
  const response = value as Partial<RpcResponse<T>>;
  return response.jsonrpc === "2.0" && response.id === 1 && ("result" in response || "error" in response);
}
