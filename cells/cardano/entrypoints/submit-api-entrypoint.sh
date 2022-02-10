#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${CARDANO_NODE_NETWORK:-}" ] && echo "CARDANO_NODE_NETWORK env var must be set -- aborting" && exit 1
[ -z "${CARDANO_NODE_SOCKET_PATH:-}" ] && echo "CARDANO_NODE_SOCKET_PATH env var must be set -- aborting" && exit 1

CARDANO_SUBMIT_API=(
  cardano-submit-api
  --socket-path "$CARDANO_NODE_SOCKET_PATH"
  --port 8090
  --listen-address "0.0.0.0"
  --config "${configFile}"
)
exec "${CARDANO_SUBMIT_API[@]}"
