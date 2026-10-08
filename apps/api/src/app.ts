import cors from "cors";
import express, { type Express } from "express";
import helmet from "helmet";

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

  return app;
}