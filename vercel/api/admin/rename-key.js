const { normalizeKey } = require("../../lib/crypto");
const { getRedis, renameKeyInRedis } = require("../../lib/redis");
const { json, readJsonBody, requireAdmin } = require("../../lib/http");

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return json(res, 405, { ok: false, error: "POST only" });
  }
  if (!requireAdmin(req, res)) {
    return;
  }

  try {
    const body = await readJsonBody(req);
    const oldKey = normalizeKey(body.old_key || body.oldKey);
    const newKey = normalizeKey(body.new_key || body.newKey);

    if (!oldKey || !newKey) {
      return json(res, 400, { ok: false, error: "Missing old_key or new_key" });
    }

    const redis = await getRedis();
    const result = await renameKeyInRedis(redis, oldKey, newKey);
    return json(res, 200, { ok: true, ...result });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
};
