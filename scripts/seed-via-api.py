#!/usr/bin/env python3
"""Push keys + accounts to fuckmark via /api/admin/import (after KV + ADMIN_SECRET are set on Vercel)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEYS_PATH = ROOT / "discord-bot" / "keys.json"
ACCOUNTS_PATH = ROOT / "discord-bot" / "accounts.json"
API_URL = os.environ.get("HOLLOW_API_URL", "https://fuckmark.vercel.app").rstrip("/")


def admin_secret() -> str:
    env_path = Path(__file__).resolve().parents[1] / ".admin-secret.txt"
    if os.environ.get("ADMIN_SECRET"):
        return os.environ["ADMIN_SECRET"].strip()
    if env_path.exists():
        return env_path.read_text(encoding="utf-8").strip()
    raise SystemExit("Set ADMIN_SECRET env var or run scripts/setup-fuckmark.ps1 first.")


def main() -> None:
    secret = admin_secret()
    keys = json.loads(KEYS_PATH.read_text(encoding="utf-8")).get("keys", [])
    accounts = json.loads(ACCOUNTS_PATH.read_text(encoding="utf-8")).get("accounts", [])

    payload = json.dumps({"keys": keys, "accounts": accounts}).encode("utf-8")
    request = urllib.request.Request(
        f"{API_URL}/api/admin/import",
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-Admin-Secret": secret,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            print(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(body, file=sys.stderr)
        if "pipeline" in body.lower():
            print(
                "\nThe live API is not updated yet or Redis env vars are wrong on Vercel.\n"
                "Use direct Redis import instead:\n"
                "  1. Create vercel/.env.local with REDIS_URL from Vercel Redis Quickstart\n"
                "  2. pip install redis\n"
                "  3. python scripts/seed-redis-url.py\n"
                "Then redeploy fuckmark with the latest vercel/ folder.",
                file=sys.stderr,
            )
        raise SystemExit(exc.code) from exc


if __name__ == "__main__":
    main()
