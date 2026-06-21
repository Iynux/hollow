export function json(res, status, body) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(body));
}

export function text(res, status, body, contentType = "text/plain; charset=utf-8") {
  res.statusCode = status;
  res.setHeader("Content-Type", contentType);
  res.end(body);
}

export async function readJsonBody(req) {
  if (req.body && typeof req.body === "object") {
    return req.body;
  }

  const raw = await new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });

  if (!raw.trim()) {
    return {};
  }
  return JSON.parse(raw);
}

export function getAdminSecret(req) {
  return req.headers["x-admin-secret"] || req.headers["X-Admin-Secret"];
}

export function requireAdmin(req, res) {
  const expected = process.env.ADMIN_SECRET;
  if (!expected) {
    json(res, 500, { ok: false, error: "ADMIN_SECRET not configured" });
    return false;
  }
  if (getAdminSecret(req) !== expected) {
    json(res, 401, { ok: false, error: "Unauthorized" });
    return false;
  }
  return true;
}
