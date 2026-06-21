import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { Redis } from "@upstash/redis";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..", "..");

const keysPath = path.join(root, "discord-bot", "keys.json");
const accountsPath = path.join(root, "discord-bot", "accounts.json");

const redis = Redis.fromEnv();

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

async function main() {
  if (!process.env.UPSTASH_REDIS_REST_URL || !process.env.UPSTASH_REDIS_REST_TOKEN) {
    throw new Error("Set UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN in .env");
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
      if (!username) continue;
      await redis.set(`account:${username}`, {
        username,
        password_hash: entry.password_hash,
        key: String(entry.key || "").trim().toUpperCase(),
        hwid: entry.hwid ?? null,
        discord_id: entry.discord_id ?? null,
        discord_name: entry.discord_name ?? null,
        registered_at: entry.registered_at ?? null,
        hwid_reset_at: entry.hwid_reset_at ?? null,
        last_login: entry.last_login ?? null,
        roblox_user: entry.roblox_user ?? null,
        roblox_user_id: entry.roblox_user_id ?? null,
      });
      accountCount += 1;
    }
  }

  console.log(`Imported ${keyCount} keys and ${accountCount} accounts into Upstash Redis.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
