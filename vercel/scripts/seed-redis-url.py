#!/usr/bin/env python3
"""Import keys + accounts using REDIS_URL from vercel/.env.local (no API needed)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERCEL_DIR = Path(__file__).resolve().parents[1]
KEYS_PATH = ROOT / "discord-bot" / "keys.json"
ACCOUNTS_PATH = ROOT / "discord-bot" / "accounts.json"
ENV_PATH = VERCEL_DIR / ".env.local"


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


def main() -> None:
    try:
        import redis
    except ImportError:
        raise SystemExit("Run: pip install redis")

    load_dotenv(ENV_PATH)
    redis_url = os.environ.get("REDIS_URL", "").strip()
    if not redis_url:
        raise SystemExit(
            "REDIS_URL missing.\n"
            f"Create {ENV_PATH} with the line from Vercel Redis Quickstart -> .env.local tab:\n"
            'REDIS_URL="redis://..."'
        )

    client = redis.from_url(redis_url, decode_responses=True)
    client.ping()
    print("Redis ping OK")

    key_count = 0
    account_count = 0

    if KEYS_PATH.exists():
        keys_data = json.loads(KEYS_PATH.read_text(encoding="utf-8"))
        for entry in keys_data.get("keys", []):
            key_value = str(entry.get("key", "")).strip().upper()
            if not key_value:
                continue
            client.set(
                f"key:{key_value}",
                json.dumps(
                    {
                        "key": key_value,
                        "script": entry.get("script") or "hollow",
                        "status": entry.get("status") or "available",
                        "discord_id": entry.get("discord_id"),
                        "discord_name": entry.get("discord_name"),
                        "claimed_at": entry.get("claimed_at"),
                        "sent_by": entry.get("sent_by"),
                    }
                ),
            )
            key_count += 1

    if ACCOUNTS_PATH.exists():
        accounts_data = json.loads(ACCOUNTS_PATH.read_text(encoding="utf-8"))
        for entry in accounts_data.get("accounts", []):
            username = str(entry.get("username", "")).strip().lower()
            key_value = str(entry.get("key", "")).strip().upper()
            if not username:
                continue
            client.set(
                f"account:{username}",
                json.dumps(
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
                    }
                ),
            )
            if key_value:
                client.set(f"keyacct:{key_value}", username)
            account_count += 1

    print(f"Imported {key_count} keys and {account_count} accounts.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
