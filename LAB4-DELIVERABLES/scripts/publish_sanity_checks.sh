#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper: keep plural command name working.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/publish_sanity_check.sh" "$@"
