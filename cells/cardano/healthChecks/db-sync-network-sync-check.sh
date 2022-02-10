#!/bin/bash

[ -z "${CARDANO_NODE_NETWORK:-}" ] && { echo "CARDANO_NODE_NETWORK env var not set"; exit 1; }

if [ "$CARDANO_NODE_NETWORK" = "testnet" ]; then
  NETWORK="--testnet-magic 1097911063"
elif [ "$CARDANO_NODE_NETWORK" = "mainnet" ]; then
  NETWORK="--mainnet"
else
  echo "CARDANO_NODE_NETWORK is not a recognized network: $CARDANO_NODE_NETWORK"
  exit 1
fi

[ -S "$CARDANO_NODE_SOCKET_PATH" ] || {
  echo "Cardano node unix domain socket at $CARDANO_NODE_SOCKET_PATH does not exist yet"
  exit 1
}

# Cardano-node in nomad appears to throw `resource vanished (Broken pipe) errors` intermittently.
# These don't appear to affect the outcome of the call, so forcing an otherwise synced node
# to ignore these errors when the json status is still correct prevents service flapping.
NODE_STATUS="$(cardano-cli query tip $NETWORK 2> /dev/null || :)"
NODE_BLOCK_HEIGHT="$(jq -e -r '.block' <<< "$NODE_STATUS" 2> /dev/null || :)"

DB_STATUS="$(curl -s localhost:8080 2> /dev/null | grep -v '#' || :)"
DB_BLOCK_HEIGHT="$(echo "$DB_STATUS" | grep -oP '^cardano_db_sync_db_block_height\s+\K[0-9]+' || :)"
echo "Cardano node status:"
jq <<< "$NODE_STATUS" || :
echo "Cardano db sync status:"
echo "$DB_STATUS" || :
echo
echo "Compare node to db blockHeight: ($NODE_BLOCK_HEIGHT, $DB_BLOCK_HEIGHT)"

# Failure modes:
[ -z "$NODE_BLOCK_HEIGHT" ] && [ -z "$DB_BLOCK_HEIGHT" ] && exit 1
[ "$NODE_BLOCK_HEIGHT" = "$DB_BLOCK_HEIGHT" ] || exit 1

