#! /usr/env bash

# Credit for the majority of code in this script goes to the spilo project:
# Ref: https://github.com/zalando/spilo/blob/master/postgres-appliance/scripts/postgres_backup.sh
#

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

PG_NODE="${PG_NODE:-"pg"}"
PGDATA="${PGDATA:-"undefined"}"
INIT_CONN_DB="${INIT_CONN_DB:-"postgres"}"
INIT_USER="${INIT_USER:-"undefined"}"
WALG_S3_PREFIX="${WALG_S3_PREFIX:-"undefined"}"
WALG_BACKUP_FROM_REPLICA="${WALG_BACKUP_FROM_REPLICA:-"undefined"}"
WALG_DAYS_TO_RETAIN="${WALG_DAYS_TO_RETAIN:-"undefined"}"
SLEEP_COUNTER="${SLEEP_COUNTER:-"undefined"}"
SLEEP_PERIOD="${SLEEP_PERIOD:-"undefined"}"

[ "$INIT_CONN_DB" = "undefined" ] && echo "INIT_CONN_DB must be defined" && exit 1
[ "$INIT_USER" = "undefined" ] && echo "INIT_USER must be defined" && exit 1
[ "$PGDATA" = "undefined" ] && echo "PGDATA must be defined" && exit 1
[ "$WALG_S3_PREFIX" = "undefined" ] && echo "WALG_S3_PREFIX must be defined" && exit 1
[ "$WALG_BACKUP_FROM_REPLICA" = "undefined" ] && echo "WALG_BACKUP_FROM_REPLICA must be defined" && exit 1
[ "$WALG_DAYS_TO_RETAIN" = "undefined" ] && echo "WALG_DAYS_TO_RETAIN must be defined" && exit 1
[ "$SLEEP_COUNTER" = "undefined" ] && echo "SLEEP_COUNTER must be defined" && exit 1
[ "$SLEEP_PERIOD" = "undefined" ] && echo "SLEEP_PERIOD must be defined" && exit 1

function log {
  echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") - $0 - $*"
}

# Leave at least 2 days base backups before creating a new one
[[ $WALG_DAYS_TO_RETAIN -lt 2 ]] && WALG_DAYS_TO_RETAIN="2"

[[ -z ${WALG_BACKUP_COMPRESSION_METHOD:-} ]] || export WALG_COMPRESSION_METHOD=$WALG_BACKUP_COMPRESSION_METHOD

while true; do
  echo
  echo "Starting postgres backup countdown timer at $(date -u +"%Y-%m-%d_%H-%M-%S")"
  echo "SLEEP_COUNTER => $SLEEP_COUNTER"
  echo "SLEEP_PERIOD => $SLEEP_PERIOD"
  echo "Sleep countdown until next walg backup in seconds is: "
  for i in $(seq 1 "$SLEEP_COUNTER"); do
    echo -n "$(((SLEEP_COUNTER - i + 1) * SLEEP_PERIOD)), "
    [ "$((i % 30))" -eq "0" ] && echo
    sleep "$SLEEP_PERIOD"
  done

  echo
  echo "Starting walg postgres backup job with:"
  echo "  INIT_CONN_DB:                    $INIT_CONN_DB"
  echo "  INIT_USER:                       $INIT_USER"
  echo "  PG_NODE:                         $PG_NODE"
  echo "  PGDATA:                          $PGDATA"
  echo "  WALG_S3_PREFIX:                  $WALG_S3_PREFIX"
  echo "  WALG_BACKUP_COMPRESSION_METHOD:  ${WALG_BACKUP_COMPRESSION_METHOD:-}"
  echo "  WALG_BACKUP_FROM_REPLICA:        $WALG_BACKUP_FROM_REPLICA"
  echo "  WALG_DAYS_TO_RETAIN:             $WALG_DAYS_TO_RETAIN"

  IN_RECOVERY="$(psql -h /alloc -U "$INIT_USER" -d "$INIT_CONN_DB" -tXqAc "select pg_is_in_recovery()")"
  if [[ $IN_RECOVERY == "f" ]]; then
    [[ $WALG_BACKUP_FROM_REPLICA == "true" ]] && log "This postgres server ($PG_NODE) is in primary mode and backups have been allowed only for replica(s) -- skipping backup" && continue
  elif [[ $IN_RECOVERY == "t" ]]; then
    [[ $WALG_BACKUP_FROM_REPLICA != "true" ]] && log "This postgres server ($PG_NODE) is in standby mode and backups have been allowed only for primary role -- skipping backup" && continue
  else
    log "ERROR: Recovery state unknown for $PG_NODE: $IN_RECOVERY" && exit 1
  fi

  BEFORE=""
  LEFT=0

  NOW=$(date +%s -u)
  while read -r name last_modified rest; do
    last_modified=$(date +%s -ud "$last_modified")
    if [ $(((NOW - last_modified) / 86400)) -ge $WALG_DAYS_TO_RETAIN ]; then
      if [ -z "$BEFORE" ] || [ "$last_modified" -gt "$BEFORE_TIME" ]; then
        BEFORE_TIME=$last_modified
        BEFORE=$name
      fi
    else
      # Count how many backups will remain after we remove everything up to certain date
      ((LEFT = LEFT + 1))
    fi
  done < <(wal-g backup-list 2>/dev/null | sed '0,/^name\s*\(last_\)\{0,1\}modified\s*/d')

  # We want keep at least N backups even if the number of days exceeded
  if [ -n "$BEFORE" ] && [ "$LEFT" -ge "$WALG_DAYS_TO_RETAIN" ]; then
    wal-g delete before FIND_FULL "$BEFORE" --confirm
  fi

  # Push a new base backup
  log "Producing a new wal-g backup"

  # Reduce the priority of the backup for CPU consumption
  nice -n 5 wal-g backup-push --full "$PGDATA" --pguser "$INIT_USER" --pgdatabase "$INIT_CONN_DB"
done
