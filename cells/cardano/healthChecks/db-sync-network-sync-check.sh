#!/bin/bash

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${envFlag:-}" ] && echo "envFlag env var must be set -- aborting" && exit 1

mapfile -t envFlag <<<"${envFlag}"

# Cardano-node in nomad appears to throw `resource vanished (Broken pipe) errors` intermittently.
# These don't appear to affect the outcome of the call, so forcing an otherwise synced node
# to ignore these errors when the json status is still correct prevents service flapping.
# shellcheck disable=SC2034,SC2068
# TODO: we should probably check slot instead of block
NODE_STATUS="$(env CARDANO_NODE_SOCKET_PATH="${socketPath}" cardano-cli query tip ${envFlag[@]} 2>/dev/null || :)"
NODE_BLOCK_HEIGHT="$(jq -e -r '.block' <<<"$NODE_STATUS" 2>/dev/null || :)"

DB_STATUS="$(curl -s localhost:8080 2>/dev/null | grep -v '#' || :)"
DB_BLOCK_HEIGHT="$(echo "$DB_STATUS" | grep -oP '^cardano_db_sync_db_block_height\s+\K[0-9]+' || :)"
echo "Cardano node status:"
jq <<<"$NODE_STATUS" || :
echo "Cardano db sync status:"
echo "$DB_STATUS" || :
echo
echo "Compare node to db blockHeight: ($NODE_BLOCK_HEIGHT, $DB_BLOCK_HEIGHT)"

# Failure modes:
[ -z "$NODE_BLOCK_HEIGHT" ] && [ -z "$DB_BLOCK_HEIGHT" ] && exit 1
# Exits as a warning if DB Sync is more than 10 blocks behind node
[ $(("$NODE_BLOCK_HEIGHT" - "$DB_BLOCK_HEIGHT")) -le 10 ] || exit 1
