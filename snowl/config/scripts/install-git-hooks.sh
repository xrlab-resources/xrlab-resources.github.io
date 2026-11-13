#!/usr/bin/env bash
# Install version-controlled git hooks for this repository.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/validate-config.sh

echo "Git hooks installed. Pre-push will validate JSON."
echo "Run ./scripts/validate-config.sh manually anytime."
echo "Bypass with: git push --no-verify"
