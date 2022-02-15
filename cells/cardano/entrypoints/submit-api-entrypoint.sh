#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${envFlag:-}" ] && echo "envFlag env var must be set -- aborting" && exit 1
[ -z "${configFile:-}" ] && echo "configFile env var must be set -- aborting" && exit 1

cmd=(
  cardano-submit-api
  --socket-path "${socketPath}"
  --port 8090
  --listen-address "0.0.0.0"
  --config "${configFile}"
  "${envFlag}"
)
exec "${cmd[@]}"