#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${envFlag:-}" ] && echo "envFlag env var must be set -- aborting" && exit 1
[ -z "${walletEnvFlag:-}" ] && echo "walletEnvFlag env var must be set -- aborting" && exit 1
[ -z "${stateDir:-}" ] && echo "stateDir env var must be set -- aborting" && exit 1

mapfile -t envFlag <<<"${envFlag}"

until [ -S "${socketPath}" ]; do
  echo "Waiting 10 seconds for cardano-node socket file at ${socketPath}..."
  sleep 10
done

# shellcheck disable=SC2068
GET_PROGRESS() {
  # shellcheck disable=SC2034
  SYNC_PERCENT="$(env CARDANO_NODE_SOCKET_PATH="${socketPath}" cardano-cli query tip ${envFlag[@]} | jq -e -r .syncProgress || :)"
}

# Ensure the upstream node listener is validated as synced.
SYNC_PERCENT=""
while [ "$SYNC_PERCENT" != "100.00" ]; do
  GET_PROGRESS
  echo "$(date -u -Iseconds)  --  Cardano node sync progress: $SYNC_PERCENT, waiting for 100.00 percent..."
  sleep 10
done
echo "Cardano node synchronized."

mkdir -p "${stateDir}/db"

# shellcheck disable=SC2206
cmd=(
  cardano-wallet serve
  --listen-address 0.0.0.0
  --port 8090
  ${walletEnvFlag}
  --node-socket ${socketPath}
  --database "${stateDir}/db"
)

# Wallet will not export prometheus metrics without also enabling EKG
export CARDANO_WALLET_EKG_HOST=127.0.0.1
export CARDANO_WALLET_EKG_PORT=8083
export CARDANO_WALLET_PROMETHEUS_HOST=127.0.0.1
export CARDANO_WALLET_PROMETHEUS_PORT=8082
"${cmd[@]}"
