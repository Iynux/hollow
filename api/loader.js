const fs = require("fs");
const path = require("path");
const { text } = require("../lib/http");

module.exports = (_req, res) => {
  const candidates = [
    path.join(process.cwd(), "public", "loader.lua"),
    path.join(process.cwd(), "api", "loader-body.lua"),
  ];

  for (const filePath of candidates) {
    if (fs.existsSync(filePath)) {
      return text(res, 200, fs.readFileSync(filePath, "utf8"));
    }
  }

  return text(res, 500, "-- loader missing on server");
};
