#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${cwdPath:-}" ] && echo "cwdPath env var must be set -- aborting" && exit 1
[ -z "${logdirPath:-}" ] && echo "logdirPath env var must be set -- aborting" && exit 1
[ -z "${stateDir:-}" ] && echo "stateDir env var must be set -- aborting" && exit 1

stateDir="${stateDir/#\~/$HOME}"

mkdir -p "${stateDir}"

cmd=(
  cardano-db-sync
  --config "${configFile}"
  --socket-path "${socketPath}"
  --schema-dir "${schemaDir}"
  --state-dir "${stateDir}"
)
exec "${cmd[@]}"
