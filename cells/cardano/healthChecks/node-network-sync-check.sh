#!/bin/bash

[ -z "''${CARDANO_NODE_NETWORK:-}" ] && { echo "CARDANO_NODE_NETWORK env var not set"; exit 1; }

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
STATUS="$(cardano-cli query tip $NETWORK 2> /dev/null || :)"
jq <<< "$STATUS" || :
jq -e '.syncProgress == "100.00"' <<< "$STATUS" || exit 1

