#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${port:-}" ] && echo "port env var must be set -- aborting" && exit 1

echo "Socat UDS to port task starting..."
until [ -S "${socketPath}" ]; do echo "Waiting for UDS at ${socketPath}"; sleep 5; done
echo "UDS at ${socketPath} found, socat piping to tcp port ${port}"
exec socat -dd "TCP-LISTEN:${port},reuseaddr,fork" "UNIX-CONNECT:${socketPath}"
