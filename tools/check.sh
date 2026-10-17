#!/usr/bin/env bash
# Local gate before every PR: syntax, TOC consistency, headless smoke test.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m pip install -q lupa >/dev/null 2>&1 || true
python3 tools/syntax.py
python3 tools/smoke.py
