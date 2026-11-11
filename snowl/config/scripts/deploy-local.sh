#!/usr/bin/env bash
# Local deploy mirroring .gitea/workflows/deploy-nextcloud.yml
# Use while Gitea act_runner is unavailable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy-dest.sh
source "${SCRIPT_DIR}/deploy-dest.sh"

BRANCH="${1:-$(git branch --show-current)}"
REMOTE="${RCLONE_REMOTE:-owltools}"
DEST="$(deploy_dest_for_branch "$BRANCH")"

export RCLONE_NO_CHECK_CERTIFICATE=true

echo "Deploying branch '$BRANCH' to ${REMOTE}:${DEST}"
rclone lsd "${REMOTE}:" --no-check-certificate
rclone mkdir "${REMOTE}:${DEST}" --no-check-certificate
rclone sync . "${REMOTE}:${DEST}" \
  --no-check-certificate \
  --exclude ".git/**" \
  --exclude ".gitea/**" \
  --exclude ".githooks/**" \
  --exclude ".claude/**" \
  --exclude ".cursor/**" \
  --exclude ".superpowers/**" \
  --exclude ".gitignore" \
  --exclude ".vscode/**" \
  --exclude "__pycache__/**" \
  --exclude ".pyc" \
  --progress

echo "Deploy complete."
