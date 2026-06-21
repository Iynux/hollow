import { normalizeKey } from "../../lib/crypto.js";
import { getRedis, keyRecordKey } from "../../lib/redis.js";
import { json, readJsonBody, requireAdmin } from "../../lib/http.js";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return json(res, 405, { ok: false, error: "POST only" });
  }
  if (!requireAdmin(req, res)) {
    return;
  }

  try {
    const body = await readJsonBody(req);
    const keys = Array.isArray(body.keys) ? body.keys : [];
    const redis = getRedis();
    let written = 0;

    for (const entry of keys) {
      const keyValue = normalizeKey(entry.key);
      if (!keyValue) continue;
      await redis.set(keyRecordKey(keyValue), {
        key: keyValue,
        script: entry.script || "hollow",
        status: entry.status || "available",
        discord_id: entry.discord_id ?? null,
        discord_name: entry.discord_name ?? null,
        claimed_at: entry.claimed_at ?? null,
        sent_by: entry.sent_by ?? null,
      });
      written += 1;
    }

    return json(res, 200, { ok: true, written });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
}
