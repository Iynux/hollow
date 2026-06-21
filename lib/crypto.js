import crypto from "crypto";

export function hashPassword(password) {
  return crypto.createHash("sha256").update(String(password)).digest("hex");
}

export function randomToken(bytes = 24) {
  return crypto.randomBytes(bytes).toString("hex");
}

export function normalizeKey(key) {
  return String(key || "").trim().toUpperCase();
}

export function normalizeUsername(username) {
  return String(username || "").trim().toLowerCase();
}
