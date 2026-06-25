const CLIENT_HEADER = process.env.HOLLOW_CLIENT_HEADER || "hollow-loader-v1";

const SECURITY_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Permissions-Policy": "interest-cohort=()",
};

function applySecurityHeaders(res, extra = {}) {
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    res.setHeader(key, value);
  }
  for (const [key, value] of Object.entries(extra)) {
    res.setHeader(key, value);
  }
}

function clientIp(req) {
  const forwarded = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim();
  return forwarded || req.socket?.remoteAddress || "unknown";
}

function isBrowserOrScraper(req) {
  const ua = String(req.headers["user-agent"] || "").toLowerCase();
  if (!ua) {
    return false;
  }
  if (ua.includes("hollowloader") || ua.includes("roblox")) {
    return false;
  }
  return (
    ua.includes("mozilla")
    || ua.includes("chrome")
    || ua.includes("safari")
    || ua.includes("curl")
    || ua.includes("wget")
    || ua.includes("python-requests")
    || ua.includes("postman")
  );
}

function protectedEndpointHtml() {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Protected Endpoint</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: #000;
      color: #fff;
      font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
    }
    main { text-align: center; padding: 32px 24px; }
    h1 {
      font-size: clamp(2rem, 6vw, 3rem);
      font-weight: 700;
      letter-spacing: -0.02em;
      margin-bottom: 16px;
    }
    p {
      font-size: clamp(1rem, 2.5vw, 1.15rem);
      color: #9b59ff;
      max-width: 520px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <main>
    <h1>Protected Endpoint</h1>
    <p>This endpoint is only accessible through the script loader.</p>
  </main>
</body>
</html>`;
}

function hasValidClient(req) {
  const value = req.headers["x-hollow-client"] || req.headers["X-Hollow-Client"];
  return value === CLIENT_HEADER;
}

function isValidToken(token) {
  return typeof token === "string" && /^[a-f0-9]{32,64}$/i.test(token.trim());
}

async function checkRateLimit(redis, bucket, max, windowSec) {
  if (!redis || typeof redis.incr !== "function") {
    return true;
  }

  const key = `rl:${bucket}`;
  try {
    const count = await redis.incr(key);
    if (count === 1) {
      if (typeof redis.expire === "function") {
        await redis.expire(key, windowSec);
      } else if (typeof redis.set === "function") {
        await redis.set(key, count, { ex: windowSec });
      }
    }
    return count <= max;
  } catch {
    return true;
  }
}

async function enforceApiAccess(req, res, redis, options = {}) {
  applySecurityHeaders(res);

  if (req.method === "HEAD") {
    res.statusCode = 405;
    res.end("-- method not allowed");
    return false;
  }

  if (options.requireClient !== false && !hasValidClient(req)) {
    res.statusCode = 403;
    res.end("-- forbidden");
    return false;
  }

  if (options.blockBrowser !== false && isBrowserOrScraper(req)) {
    res.statusCode = 403;
    res.end("-- forbidden");
    return false;
  }

  const ip = clientIp(req);
  const ipOk = await checkRateLimit(
    redis,
    `ip:${options.route || "api"}:${ip}`,
    options.ipLimit || 120,
    options.ipWindow || 60,
  );
  if (!ipOk) {
    res.statusCode = 429;
    res.end("-- rate limited");
    return false;
  }

  return true;
}

module.exports = {
  CLIENT_HEADER,
  applySecurityHeaders,
  clientIp,
  isBrowserOrScraper,
  protectedEndpointHtml,
  hasValidClient,
  isValidToken,
  checkRateLimit,
  enforceApiAccess,
};
