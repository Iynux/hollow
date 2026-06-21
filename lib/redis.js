import { Redis } from "@upstash/redis";

let client;

export function getRedis() {
  if (!client) {
    client = Redis.fromEnv();
  }
  return client;
}

export function accountKey(username) {
  return `account:${String(username).toLowerCase()}`;
}

export function keyRecordKey(keyValue) {
  return `key:${String(keyValue).toUpperCase()}`;
}

export function tokenKey(token) {
  return `token:${token}`;
}
