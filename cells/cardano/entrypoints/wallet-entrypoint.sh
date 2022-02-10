#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${CARDANO_NODE_NETWORK:-}" ] && echo "CARDANO_NODE_NETWORK env var must be set -- aborting" && exit 1
[ -z "${CARDANO_NODE_SOCKET_PATH:-}" ] && echo "CARDANO_NODE_SOCKET_PATH env var must be set -- aborting" && exit 1
[ -z "${CARDANO_NODE_SYNCED_SERVICE:-}" ] && echo "CARDANO_NODE_SYNCED_SERVICE env var must be set -- aborting" && exit 1
[ -z "${CARDANO_WALLET_STATE_DIR:-}" ] && echo "CARDANO_WALLET_STATE_DIR env var must be set -- aborting" && exit 1

if [ "$CARDANO_NODE_NETWORK" = "testnet" ]; then
  echo "Starting cardano-wallet on the testnet environment..."
  CLI_ARGS=("--testnet-magic 1097911063")
  NETWORK="testnet"
elif [ "$CARDANO_NODE_NETWORK" = "mainnet" ]; then
  echo "Starting cardano-wallet on the mainnet environment..."
  CLI_ARGS=("--mainnet")
  NETWORK="mainnet"
else
  echo "CARDANO_NODE_NETWORK is not a recognized network: $CARDANO_NODE_NETWORK -- aborting"
  exit 1
fi

WALLET_HOME="$CARDANO_WALLET_STATE_DIR/${NETWORK}"
WALLET_DB="${WALLET_HOME}/db"
mkdir -p "$WALLET_DB"
GENESIS_FILE="byron-genesis.json"
GENESIS_URL="https://raw.githubusercontent.com/input-output-hk/iohk-nix/master/cardano-lib/${NETWORK}/${GENESIS_FILE}"

if [ "$NETWORK" = "testnet" ]; then
  if [ ! -f "${WALLET_HOME}/${GENESIS_FILE}" ]; then
    echo "Byron genesis file NOT found at: ${WALLET_HOME}/${GENESIS_FILE}"
    echo "Fetching byron genesis file for ${NETWORK}..."
    if ! curl -fLv $GENESIS_URL -o "${WALLET_HOME}/${GENESIS_FILE}"; then
      echo "Unable to obtain byron genesis file for $NETWORK -- aborting"
      exit 1
    else
      echo "Obtained byron genesis file for ${NETWORK}..."
    fi
  else
    echo "Byron genesis file found at: ${WALLET_HOME}/${GENESIS_FILE}"
  fi
  NETWORK_CLI_STRING="--testnet ${WALLET_HOME}/${GENESIS_FILE}"
else
  NETWORK_CLI_STRING="--mainnet"
fi

# For connect services with port to socket tasks via socat,
# a socket will become available quickly, although it will
# not necessarily have a route to an active listener.
until [ -S "$CARDANO_NODE_SOCKET_PATH" ]; do
  echo "Waiting 10 seconds for cardano-node socket file at $CARDANO_NODE_SOCKET_PATH..."
  sleep 10;
done

# To avoid unexpected behavior ensure a healthy synced node has become available.
# A consul prepared query is used as a connect query would return both synced and unsynced nodes.
while [ "$(dig +short "${CARDANO_NODE_SYNCED_SERVICE}.query.consul")" = "" ]; do
  echo "Waiting 10 seconds for a synced cardano-node to join the connect service $CARDANO_NODE_SYNCED_SERVICE..."
  sleep 10;
done

# shellcheck disable=SC2068
GET_PROGRESS () {
  SYNC_PERCENT="$(cardano-cli query tip ${CLI_ARGS[@]} | jq -e -r .syncProgress || :)"
}

# Ensure the upstream node listener is validated as synced.
SYNC_PERCENT=""
while [ "$SYNC_PERCENT" != "100.00" ]; do
  GET_PROGRESS
  echo "$(date -u -Iseconds)  --  Cardano node sync progress: $SYNC_PERCENT, waiting for 100.00 percent..."
  sleep 10;
done
echo "Cardano node synchronized."

# shellcheck disable=SC2206
WALLET_SERVER=(
  cardano-wallet serve
  --listen-address 0.0.0.0
  --port 8090
  $NETWORK_CLI_STRING
  --node-socket $CARDANO_NODE_SOCKET_PATH
  --database "$WALLET_DB"
)
exec "${WALLET_SERVER[@]}"

