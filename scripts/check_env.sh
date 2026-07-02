#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".env" ]; then
  echo "Missing .env file. Copy .env.example to .env"
  exit 1
fi

echo ".env file found"
