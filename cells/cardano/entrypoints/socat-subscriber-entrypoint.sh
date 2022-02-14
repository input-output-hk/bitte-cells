#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${port:-}" ] && echo "port env var must be set -- aborting" && exit 1

echo "Socat port to UDS task starting..."
until nc -W1 -w1 -v localhost "${port}"; do echo "Waiting for port listener at ${port}"; sleep 5; done
echo "Port at ${port} found listening, socat piping to UDS at ${socketPath}"
exec socat -dd "UNIX-LISTEN:${socketPath},fork,reuseaddr,unlink-early" "TCP:localhost:${port}"
