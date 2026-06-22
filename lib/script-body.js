const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

function sha256(text) {
  return crypto.createHash("sha256").update(text, "utf8").digest("hex").slice(0, 12);
}

function scriptCandidates() {
  const cwd = process.cwd();
  return [
    path.join(cwd, "hollow.lua"),
    path.join(cwd, "private", "hollow.lua"),
    path.join(cwd, "..", "hollow.lua"),
  ];
}

function loadScriptBody() {
  for (const filePath of scriptCandidates()) {
    if (!fs.existsSync(filePath)) continue;
    const body = fs.readFileSync(filePath, "utf8");
    if (body && body.trim() !== "") {
      return { body, filePath };
    }
  }
  return null;
}

function readScriptInfo() {
  const loaded = loadScriptBody();
  if (!loaded) {
    return null;
  }

  const buildMatch = loaded.body.match(/^--\s*HOLLOW_BUILD:([^\r\n]+)/);
  return {
    body: loaded.body,
    filePath: loaded.filePath,
    hash: sha256(loaded.body),
    build: buildMatch ? buildMatch[1].trim() : null,
    bytes: Buffer.byteLength(loaded.body, "utf8"),
  };
}

module.exports = {
  loadScriptBody,
  readScriptInfo,
  scriptCandidates,
};
