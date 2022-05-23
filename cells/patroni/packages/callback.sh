#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${PERSISTENCE_MOUNTPOINT:-}" ] && echo "PERSISTENCE_MOUNTPOINT env var must be set -- aborting" && exit 1

export PGDATA="$PERSISTENCE_MOUNTPOINT/postgres/patroni"

echo "Patroni callback initiated with args of: $*"

if [ $# -eq 0 ]; then
  echo "This callback script requires at least one argument defining the patroni callback method:"
  echo "on_reload, on_restart, on_role_change, on_start, on_stop, post_bootstrap, post_init"
  exit 1
fi

METHOD=$1
if ! [[ $METHOD =~ ^on_(reload|restart|role_change|start|stop)$|^post_(bootstrap|init)$ ]]; then
  echo "The patroni callback method is unrecognized: $METHOD"
  exit 1
fi

echo "Patroni callback initiated with method: $METHOD"

# Workaround for ownership issue where postgres cannot use SIGHUP in a nomad job
# for consul template cert refresh yet due to required ownership change.
#
# Patroni enables callback hooks to be used on SIGHUP to script ownership change
# and then SIGHUP postgres.
#
# Ref: https://github.com/hashicorp/nomad/issues/5020#issuecomment-8228130620
echo
echo "Signaling postgres to reload configuration files"
pg_ctl reload

echo "Finished callback for method: $METHOD"
