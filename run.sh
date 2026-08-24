#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pkill -x menote 2>/dev/null || true

"$ROOT/scripts/package_app.sh" debug

sleep 1
open "$ROOT/build/menote.app"

echo "menote launched."
