const { json } = require("../lib/http");
const { readScriptInfo, scriptCandidates } = require("../lib/script-body");

module.exports = async (_req, res) => {
  const info = readScriptInfo();
  if (!info) {
    return json(res, 500, {
      ok: false,
      error: "hollow.lua not found on server",
      searched: scriptCandidates(),
    });
  }

  return json(res, 200, {
    ok: true,
    build: info.build,
    hash: info.hash,
    bytes: info.bytes,
    file: String(info.filePath || "").split(/[\\/]/).pop(),
  });
};
