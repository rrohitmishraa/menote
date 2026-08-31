#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT/scripts/package_app.sh" release

cd "$ROOT/build"
rm -f menote-3.0.0.zip
zip -qry menote-3.0.0.zip menote.app
echo "Release zip: $ROOT/build/menote-3.0.0.zip"
