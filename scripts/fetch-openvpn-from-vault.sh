#!/usr/bin/env bash
set -euo pipefail

# Fetch OpenVPN secrets from Vault via HTTP API (cubbyhole/openvpn).
#
# Usage:
#   export VAULT_ADDR="https://wars.lan"
#   export VAULT_TOKEN="hvs...."
#   ./scripts/fetch-openvpn-from-vault.sh
#
# Output:
#   ./secrets/openvpn/ca.crt
#   ./secrets/openvpn/client.crt
#   ./secrets/openvpn/client.key
#   ./secrets/openvpn/tls-auth.key
#
# Notes:
# - This script is intentionally "impure": it requires network + token at build time.
# - Files are NOT committed (secrets/ is in .gitignore).

VAULT_ADDR="${VAULT_ADDR:-}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
VAULT_PATH="${VAULT_PATH:-cubbyhole/openvpn}"

if [[ -z "$VAULT_ADDR" ]]; then
  echo "ERROR: VAULT_ADDR is empty (e.g. https://vault.example.lan)" >&2
  exit 1
fi
if [[ -z "$VAULT_TOKEN" ]]; then
  echo "ERROR: VAULT_TOKEN is empty" >&2
  exit 1
fi

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/secrets/openvpn"
mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSk \
  -H 'accept: */*' \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$VAULT_PATH" > "$tmp"

jq -er '.data.ca' "$tmp" > "$OUT_DIR/ca.crt"
jq -er '.data.cert' "$tmp" > "$OUT_DIR/client.crt"
jq -er '.data.key' "$tmp" > "$OUT_DIR/client.key"
jq -er '.data["tls-auth"]' "$tmp" > "$OUT_DIR/tls-auth.key"

chmod 0400 "$OUT_DIR/client.key" "$OUT_DIR/tls-auth.key"
chmod 0444 "$OUT_DIR/ca.crt" "$OUT_DIR/client.crt"

echo "Wrote:"
ls -la "$OUT_DIR"

