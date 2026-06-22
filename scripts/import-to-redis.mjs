import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { Redis } from "@upstash/redis";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..", "..");

const keysPath = path.join(root, "discord-bot", "keys.json");
const accountsPath = path.join(root, "discord-bot", "accounts.json");

function resolveRedisConfig() {
  const url =
    process.env.UPSTASH_REDIS_REST_URL ||
    process.env.KV_REST_API_URL ||
    process.env.KV_URL;
  const token =
    process.env.UPSTASH_REDIS_REST_TOKEN ||
    process.env.KV_REST_API_TOKEN;

  if (url && token) {
    return new Redis({ url, token });
  }
  return Redis.fromEnv();
}

const redis = resolveRedisConfig();

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function keyAccountKey(keyValue) {
  return `keyacct:${String(keyValue).toUpperCase()}`;
}

async function main() {
  const hasKv =
    process.env.UPSTASH_REDIS_REST_URL ||
    process.env.KV_REST_API_URL ||
    process.env.KV_URL;
  const hasToken =
    process.env.UPSTASH_REDIS_REST_TOKEN ||
    process.env.KV_REST_API_TOKEN;

  if (!hasKv || !hasToken) {
    throw new Error(
      "Set Vercel KV or Upstash env vars (KV_REST_API_URL + KV_REST_API_TOKEN, or UPSTASH_REDIS_REST_URL + UPSTASH_REDIS_REST_TOKEN)"
    );
  }

  let keyCount = 0;
  let accountCount = 0;

  if (fs.existsSync(keysPath)) {
    const keysData = readJson(keysPath);
    for (const entry of keysData.keys || []) {
      const keyValue = String(entry.key || "").trim().toUpperCase();
      if (!keyValue) continue;
      await redis.set(`key:${keyValue}`, {
        key: keyValue,
        script: entry.script || "hollow",
        status: entry.status || "available",
        discord_id: entry.discord_id ?? null,
        discord_name: entry.discord_name ?? null,
        claimed_at: entry.claimed_at ?? null,
        sent_by: entry.sent_by ?? null,
      });
      keyCount += 1;
    }
  }

  if (fs.existsSync(accountsPath)) {
    const accountsData = readJson(accountsPath);
    for (const entry of accountsData.accounts || []) {
      const username = String(entry.username || "").trim().toLowerCase();
      const keyValue = String(entry.key || "").trim().toUpperCase();
      if (!username) continue;
      await redis.set(`account:${username}`, {
        username,
        password_hash: entry.password_hash,
        key: keyValue,
        hwid: entry.hwid ?? null,
        discord_id: entry.discord_id ?? null,
        discord_name: entry.discord_name ?? null,
        registered_at: entry.registered_at ?? null,
        hwid_reset_at: entry.hwid_reset_at ?? null,
        last_login: entry.last_login ?? null,
        roblox_user: entry.roblox_user ?? null,
        roblox_user_id: entry.roblox_user_id ?? null,
      });
      if (keyValue) {
        await redis.set(keyAccountKey(keyValue), username);
      }
      accountCount += 1;
    }
  }

  console.log(`Imported ${keyCount} keys and ${accountCount} accounts into Vercel KV / Redis.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
