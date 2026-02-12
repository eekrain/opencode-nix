#!/usr/bin/env bash
# update-kilocode.sh - Check for and apply Kilo Code CLI version updates
# Usage:
#   ./update-kilocode.sh          # Check for updates, output UPDATE_NEEDED and NEW_VERSION
#   ./update-kilocode.sh --update # Actually update kilocode-version.json with new hashes

set -euo pipefail

VERSION_FILE="$(dirname "$0")/kilocode-version.json"
PACKAGE_METADATA_URL="https://registry.npmjs.org/@kilocode/cli/latest"

# Get current version from kilocode-version.json
get_current_version() {
  jq -r '.version' "$VERSION_FILE"
}

# Query npm registry for latest @kilocode/cli version
get_latest_version() {
  local metadata
  metadata=$(curl -fsSL "$PACKAGE_METADATA_URL")
  echo "$metadata" | jq -r '.version // empty'
}

# Convert nix-prefetch-url output (base32) to SRI format
hash_to_sri() {
  local hash="$1"
  nix hash convert --hash-algo sha256 --to sri "$hash"
}

# Fetch hash for a given URL
fetch_hash() {
  local url="$1"
  local hash
  hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
  hash_to_sri "$hash"
}

# Map Nix platform -> npm package tarball path
get_download_url() {
  local version="$1"
  local platform="$2"

  case "$platform" in
    x86_64-linux)
      echo "https://registry.npmjs.org/@kilocode/cli-linux-x64/-/cli-linux-x64-${version}.tgz"
      ;;
    aarch64-linux)
      echo "https://registry.npmjs.org/@kilocode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz"
      ;;
    x86_64-darwin)
      echo "https://registry.npmjs.org/@kilocode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz"
      ;;
    aarch64-darwin)
      echo "https://registry.npmjs.org/@kilocode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz"
      ;;
    *)
      echo "Unknown platform: $platform" >&2
      return 1
      ;;
  esac
}

# Check if stored hash matches current upstream hash (spot check one platform)
verify_current_hash() {
  local version="$1"
  local platform="x86_64-linux" # Use linux x64 as the canary

  local stored_hash
  stored_hash=$(jq -r ".hashes[\"$platform\"]" "$VERSION_FILE")

  local url
  url=$(get_download_url "$version" "$platform")

  local current_hash
  current_hash=$(fetch_hash "$url")

  [[ "$stored_hash" == "$current_hash" ]]
}

main() {
  local update_mode=false

  if [[ "${1:-}" == "--update" ]]; then
    update_mode=true
  fi

  local current_version
  current_version=$(get_current_version)

  local latest_version
  latest_version=$(get_latest_version)

  if [[ -z "$latest_version" ]]; then
    echo "ERROR: Could not fetch latest version from npm registry" >&2
    exit 1
  fi

  if [[ "$current_version" == "$latest_version" ]]; then
    echo "Verifying upstream hash hasn't changed..." >&2
    if verify_current_hash "$current_version"; then
      echo "UPDATE_NEEDED=false"
      echo "NEW_VERSION=$current_version"
      exit 0
    else
      echo "Hash mismatch detected - upstream rebuilt $current_version" >&2
      latest_version="$current_version"
    fi
  fi

  echo "UPDATE_NEEDED=true"
  echo "NEW_VERSION=$latest_version"

  if [[ "$update_mode" == true ]]; then
    echo "Updating kilocode-version.json to $latest_version..." >&2

    local platforms=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin")

    local json_content
    json_content=$(cat <<EOF
{
  "version": "$latest_version",
  "hashes": {
EOF
)

    local first=true
    for platform in "${platforms[@]}"; do
      local url
      url=$(get_download_url "$latest_version" "$platform")
      echo "Fetching hash for $platform..." >&2

      local hash
      hash=$(fetch_hash "$url")

      if [[ "$first" == true ]]; then
        first=false
      else
        json_content+=","
      fi
      json_content+=$'\n'"    \"$platform\": \"$hash\""
    done

    json_content+=$'\n'"  }"$'\n'"}"

    echo "$json_content" > "$VERSION_FILE"
    echo "Updated kilocode-version.json successfully!" >&2
  fi
}

main "$@"
