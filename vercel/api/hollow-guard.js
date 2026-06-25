const { text } = require("../lib/http");
const {
  applySecurityHeaders,
  isBrowserOrScraper,
  protectedEndpointHtml,
} = require("../lib/security");

module.exports = (req, res) => {
  applySecurityHeaders(res);

  if (isBrowserOrScraper(req)) {
    res.statusCode = 403;
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.end(protectedEndpointHtml());
    return;
  }

  return text(res, 403, "-- private; authenticate with loader.lua");
};
