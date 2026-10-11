import cors from "cors";
import express, { type Express } from "express";
import helmet from "helmet";
import { RpcEvidenceCollector } from "./credit/rpcEvidence.js";
import { calculateAssessment, deriveFeatures } from "./credit/scoring.js";
import { buildUnsignedProfileUpdate } from "./credit/profileUpdate.js";
import { isAddress } from "./credit/validation.js";

export function createApp(): Express {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      service: "credence-api",
    });
  });

  const rpcUrl = process.env.CREDENCE_RPC_URL;
  const chainId = Number(process.env.CREDENCE_CHAIN_ID);
  const registryAddress = process.env.CREDENCE_CREDIT_REGISTRY;
  const collector =
    rpcUrl && Number.isSafeInteger(chainId) && chainId > 0 ? new RpcEvidenceCollector({ rpcUrl, chainId }) : undefined;

  app.get("/wallet/:address/evidence", async (req, res) => {
    if (!collector || !isAddress(req.params.address)) {
      res.status(400).json({ error: "Configured RPC and a valid wallet address are required" });
      return;
    }
    try {
      res.json(await collector.collect(req.params.address));
    } catch (error) {
      res.status(502).json({ error: "Evidence collection failed" });
    }
  });

  app.get("/wallet/:address/features", async (req, res) => {
    if (!collector || !isAddress(req.params.address)) {
      res.status(400).json({ error: "Configured RPC and a valid wallet address are required" });
      return;
    }
    try {
      res.json(deriveFeatures(await collector.collect(req.params.address)));
    } catch (error) {
      res.status(502).json({ error: "Feature derivation failed" });
    }
  });

  app.get("/wallet/:address/profile", async (req, res) => {
    if (!collector || !isAddress(req.params.address)) {
      res.status(400).json({ error: "Configured RPC and a valid wallet address are required" });
      return;
    }
    try {
      res.json(calculateAssessment(await collector.collect(req.params.address)));
    } catch (error) {
      res.status(502).json({ error: "Scoring failed" });
    }
  });

  app.post("/wallet/:address/profile-update", async (req, res) => {
    if (!collector || !registryAddress || !isAddress(req.params.address)) {
      res.status(400).json({ error: "Configured RPC, registry, and a valid wallet address are required" });
      return;
    }
    try {
      const assessment = calculateAssessment(await collector.collect(req.params.address));
      res.json(buildUnsignedProfileUpdate(registryAddress, assessment));
    } catch (error) {
      res.status(502).json({ error: "Profile update preparation failed" });
    }
  });

  return app;
}