#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${stateDir:-}" ] && echo "stateDir env var must be set -- aborting" && exit 1
[ -z "${envFlag:-}" ] && echo "envFlag env var must be set -- aborting" && exit 1

mapfile -t envFlag <<< "${envFlag}"

[ -z "${CARDANO_NODE_SYNCED_SERVICE:-}" ] && echo "CARDANO_NODE_SYNCED_SERVICE env var must be set -- aborting" && exit 1

# For connect services with port to socket tasks via socat,
# a socket will become available quickly, although it will
# not necessarily have a route to an active listener.
until [ -S "${socketPath}" ]; do
  echo "Waiting 10 seconds for cardano-node socket file at ${socketPath}..."
  sleep 10
done

# To avoid unexpected behavior ensure a healthy synced node has become available.
# A consul prepared query is used as a connect query would return both synced and unsynced nodes.
while [ "$(dig +short "${CARDANO_NODE_SYNCED_SERVICE}.query.consul")" = "" ]; do
  echo "Waiting 10 seconds for a synced cardano-node to join the connect service $CARDANO_NODE_SYNCED_SERVICE..."
  sleep 10
done

# shellcheck disable=SC2068
GET_PROGRESS() {
  # shellcheck disable=SC2034
  SYNC_PERCENT="$(env CARDANO_NODE_SOCKET_PATH="${socketPath}" cardano-cli query tip ${envFlag[@]} | jq -e -r .syncProgress || :)"
}

SYNC_PERCENT=""
while [ "$SYNC_PERCENT" != "100.00" ]; do
  GET_PROGRESS
  echo "$(date -u -Iseconds)  --  Cardano node sync progress: $SYNC_PERCENT, waiting for 100.00 percent..."
  sleep 10
done
echo "Cardano node synchronized."

# shellcheck disable=SC2206
cmd=(
  cardano-db-sync
  --config "${configFile}"
  --socket-path ${socketPath}
  --schema-dir "${schemaDir}"
  --state-dir "${stateDir}"
)
exec "${cmd[@]}"
