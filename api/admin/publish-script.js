const { getRedis } = require("../../lib/redis");
const { setLiveScript } = require("../../lib/script-store");
const { json, readJsonBody, requireAdmin } = require("../../lib/http");

function readRawBody(req) {
  if (typeof req.body === "string") {
    return Promise.resolve(req.body);
  }

  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return json(res, 405, { ok: false, error: "POST only" });
  }
  if (!requireAdmin(req, res)) {
    return;
  }

  try {
    const contentType = String(req.headers["content-type"] || "").toLowerCase();
    let script = "";

    if (contentType.includes("text/plain") || contentType.includes("application/octet-stream")) {
      script = await readRawBody(req);
    } else {
      const body = await readJsonBody(req);
      script = String(body.script || "");
    }

    const redis = await getRedis();
    const meta = await setLiveScript(redis, script);

    return json(res, 200, {
      ok: true,
      message: "Script published to Redis",
      script: meta,
    });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
};
