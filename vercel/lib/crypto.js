const crypto = require("crypto");

function hashPassword(password) {
  return crypto.createHash("sha256").update(String(password)).digest("hex");
}

function randomToken(bytes = 24) {
  return crypto.randomBytes(bytes).toString("hex");
}

function normalizeKey(key) {
  return String(key || "").trim().toUpperCase();
}

function normalizeUsername(username) {
  return String(username || "").trim().toLowerCase();
}

module.exports = {
  hashPassword,
  randomToken,
  normalizeKey,
  normalizeUsername,
};
