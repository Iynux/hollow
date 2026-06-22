const { getRedis } = require("../lib/redis");

module.exports = async (_req, res) => {
  const payload = { ok: true, service: "Hollow API", storage: "kv" };

  try {
    const redis = await getRedis();
    await redis.ping();
    payload.kv = "connected";
  } catch (err) {
    payload.kv = "error";
    payload.kvError = String(err?.message || err);
  }

  res.statusCode = 200;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(payload));
};
