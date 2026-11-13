# Shared deploy destination configuration.
# Sourced by scripts/deploy-local.sh and .gitea/workflows/deploy-nextcloud.yml
DEST_ROOT="http/repositories/snowl-config"

# Return the Nextcloud path for a given branch name.
deploy_dest_for_branch() {
  echo "${DEST_ROOT}/${1}"
}
