import { readFileSync } from "fs";
import { resolve } from "path";

export interface Config {
  apiKey: string;
  apiSecret: string;
  accessToken: string;
  accessTokenSecret: string;
}

const REQUIRED_VARS = [
  "X_API_KEY",
  "X_API_SECRET",
  "X_ACCESS_TOKEN",
  "X_ACCESS_TOKEN_SECRET",
] as const;

type RequiredVar = (typeof REQUIRED_VARS)[number];

function parseEnvFile(path: string): Record<string, string> {
  try {
    const content = readFileSync(path, "utf-8");
    const vars: Record<string, string> = {};

    for (const line of content.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;

      const eqIndex = trimmed.indexOf("=");
      if (eqIndex === -1) continue;

      const key = trimmed.slice(0, eqIndex).trim();
      const raw = trimmed.slice(eqIndex + 1).trim();
      vars[key] = raw.replace(/^["']|["']$/g, "");
    }

    return vars;
  } catch {
    return {};
  }
}

function resolveVar(
  key: RequiredVar,
  envLocal: Record<string, string>,
  envFile: Record<string, string>,
): string | undefined {
  return envLocal[key] ?? envFile[key] ?? process.env[key];
}

export function loadConfig(baseDir?: string): Config {
  const dir = baseDir ?? process.cwd();
  const envLocal = parseEnvFile(resolve(dir, ".env.local"));
  const envFile = parseEnvFile(resolve(dir, ".env"));

  const missing: RequiredVar[] = [];
  const get = (key: RequiredVar): string => {
    const value = resolveVar(key, envLocal, envFile);
    if (!value) missing.push(key);
    return value ?? "";
  };

  const config: Config = {
    apiKey: get("X_API_KEY"),
    apiSecret: get("X_API_SECRET"),
    accessToken: get("X_ACCESS_TOKEN"),
    accessTokenSecret: get("X_ACCESS_TOKEN_SECRET"),
  };

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(", ")}\n` +
        `Set them in .env.local, .env, or as environment variables.`,
    );
  }

  return config;
}
