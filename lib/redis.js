const { Redis } = require("@upstash/redis");

let clientPromise;

function resolveUpstashConfig() {
  const url =
    process.env.UPSTASH_REDIS_REST_URL ||
    process.env.KV_REST_API_URL ||
    process.env.KV_URL;
  const token =
    process.env.UPSTASH_REDIS_REST_TOKEN ||
    process.env.KV_REST_API_TOKEN;

  if (url && token) {
    return { url, token };
  }
  return null;
}

function wrapNodeRedis(raw) {
  return {
    async get(key) {
      const value = await raw.get(key);
      if (value == null) return null;
      try {
        return JSON.parse(value);
      } catch {
        return value;
      }
    },
    async set(key, value, opts = {}) {
      const payload = typeof value === "string" ? value : JSON.stringify(value);
      const ttl = opts.ex ?? opts.EX;
      if (ttl) {
        await raw.set(key, payload, { EX: ttl });
        return;
      }
      await raw.set(key, payload);
    },
    async keys(pattern) {
      return raw.keys(pattern);
    },
    async ping() {
      return raw.ping();
    },
  };
}

async function connectRedis() {
  if (process.env.REDIS_URL) {
    const { createClient } = require("redis");
    const raw = createClient({ url: process.env.REDIS_URL });
    raw.on("error", (err) => {
      console.error("Redis client error:", err);
    });
    await raw.connect();
    return wrapNodeRedis(raw);
  }

  const upstash = resolveUpstashConfig();
  if (upstash) {
    return new Redis(upstash);
  }

  throw new Error(
    "Redis not configured. Connect Vercel Redis (REDIS_URL) or Upstash/KV REST env vars."
  );
}

async function getRedis() {
  if (!clientPromise) {
    clientPromise = connectRedis();
  }
  return clientPromise;
}

function accountKey(username) {
  return `account:${String(username).toLowerCase()}`;
}

function keyRecordKey(keyValue) {
  return `key:${String(keyValue).toUpperCase()}`;
}

function keyAccountKey(keyValue) {
  return `keyacct:${String(keyValue).toUpperCase()}`;
}

function tokenKey(token) {
  return `token:${token}`;
}

async function linkKeyToAccount(redis, keyValue, username) {
  const key = String(keyValue || "").trim().toUpperCase();
  const user = String(username || "").trim().toLowerCase();
  if (!key || !user) return;
  await redis.set(keyAccountKey(key), user);
}

async function findAccountByKey(redis, keyValue) {
  const normalized = String(keyValue || "").trim().toUpperCase();
  if (!normalized) return null;

  const username = await redis.get(keyAccountKey(normalized));
  if (username) {
    const account = await redis.get(accountKey(username));
    if (account) return account;
  }

  const keys = await redis.keys("account:*");
  for (const redisKey of keys) {
    const account = await redis.get(redisKey);
    if (account && String(account.key || "").trim().toUpperCase() === normalized) {
      await linkKeyToAccount(redis, normalized, account.username);
      return account;
    }
  }
  return null;
}

module.exports = {
  getRedis,
  accountKey,
  keyRecordKey,
  keyAccountKey,
  tokenKey,
  linkKeyToAccount,
  findAccountByKey,
};
