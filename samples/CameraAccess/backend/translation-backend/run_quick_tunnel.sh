#!/usr/bin/env bash
set -euo pipefail

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is not installed."
  echo "Install it first, then rerun this script."
  exit 1
fi

exec cloudflared tunnel --url http://localhost:8000
