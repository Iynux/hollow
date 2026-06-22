#!/usr/bin/env python3
"""Import discord-bot keys + accounts into Vercel KV / Upstash Redis (no Node required)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEYS_PATH = ROOT / "discord-bot" / "keys.json"
ACCOUNTS_PATH = ROOT / "discord-bot" / "accounts.json"
ENV_PATH = Path(__file__).resolve().parents[1] / ".env.local"


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def redis_config() -> tuple[str, str]:
    load_dotenv(ENV_PATH)
    url = (
        os.environ.get("UPSTASH_REDIS_REST_URL")
        or os.environ.get("KV_REST_API_URL")
        or os.environ.get("KV_URL")
        or ""
    ).rstrip("/")
    token = (
        os.environ.get("UPSTASH_REDIS_REST_TOKEN")
        or os.environ.get("KV_REST_API_TOKEN")
        or ""
    )
    if not url or not token:
        raise SystemExit(
            "Missing Redis env vars.\n"
            "Run from vercel/:  vercel env pull .env.local\n"
            "Or set KV_REST_API_URL + KV_REST_API_TOKEN (or UPSTASH_REDIS_REST_*)."
        )
    return url, token


def redis_set(url: str, token: str, key: str, value: object) -> None:
    encoded_key = urllib.parse.quote(key, safe="")
    body = json.dumps(value).encode("utf-8")
    request = urllib.request.Request(
        f"{url}/set/{encoded_key}",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read().decode("utf-8")
        data = json.loads(raw) if raw else {}
        if data.get("error"):
            raise RuntimeError(data["error"])


def redis_ping(url: str, token: str) -> None:
    request = urllib.request.Request(
        f"{url}/ping",
        method="GET",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        raw = response.read().decode("utf-8")
        if "PONG" not in raw.upper():
            raise RuntimeError(f"Unexpected ping response: {raw}")


def main() -> None:
    url, token = redis_config()
    print(f"Redis: {url[:48]}...")

    try:
        redis_ping(url, token)
        print("Ping OK")
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"Redis ping failed ({exc.code}): {exc.read().decode()}") from exc

    key_count = 0
    account_count = 0

    if KEYS_PATH.exists():
        keys_data = json.loads(KEYS_PATH.read_text(encoding="utf-8"))
        for entry in keys_data.get("keys", []):
            key_value = str(entry.get("key", "")).strip().upper()
            if not key_value:
                continue
            redis_set(
                url,
                token,
                f"key:{key_value}",
                {
                    "key": key_value,
                    "script": entry.get("script") or "hollow",
                    "status": entry.get("status") or "available",
                    "discord_id": entry.get("discord_id"),
                    "discord_name": entry.get("discord_name"),
                    "claimed_at": entry.get("claimed_at"),
                    "sent_by": entry.get("sent_by"),
                },
            )
            key_count += 1

    if ACCOUNTS_PATH.exists():
        accounts_data = json.loads(ACCOUNTS_PATH.read_text(encoding="utf-8"))
        for entry in accounts_data.get("accounts", []):
            username = str(entry.get("username", "")).strip().lower()
            key_value = str(entry.get("key", "")).strip().upper()
            if not username:
                continue
            redis_set(
                url,
                token,
                f"account:{username}",
                {
                    "username": username,
                    "password_hash": entry.get("password_hash"),
                    "key": key_value,
                    "hwid": entry.get("hwid"),
                    "discord_id": entry.get("discord_id"),
                    "discord_name": entry.get("discord_name"),
                    "registered_at": entry.get("registered_at"),
                    "hwid_reset_at": entry.get("hwid_reset_at"),
                    "last_login": entry.get("last_login"),
                    "roblox_user": entry.get("roblox_user"),
                    "roblox_user_id": entry.get("roblox_user_id"),
                },
            )
            if key_value:
                redis_set(url, token, f"keyacct:{key_value}", username)
            account_count += 1

    print(f"Imported {key_count} keys and {account_count} accounts into KV/Redis.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
