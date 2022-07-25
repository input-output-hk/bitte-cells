#! /usr/env bash

# Credit for the majority of code in this script goes to the spilo project:
# Ref: https://github.com/zalando/spilo/blob/master/postgres-appliance/scripts/postgres_backup.sh
#

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${PERSISTENCE_MOUNTPOINT:-}" ] && echo "PERSISTENCE_MOUNTPOINT env var must be set -- aborting" && exit 1

PGDATA="$PERSISTENCE_MOUNTPOINT/postgres/patroni"
PGHOST="${PGHOST:-"undefined"}"
PGPORT="${PGPORT:-"undefined"}"
PG_NODE="${PG_NODE:-"pg"}"
INIT_CONN_DB="${INIT_CONN_DB:-"postgres"}"
INIT_USER="${INIT_USER:-"undefined"}"
WALG_S3_PREFIX="${WALG_S3_PREFIX:-"undefined"}"
WALG_BACKUP_COMPRESSION_METHOD="${WALG_BACKUP_COMPRESSION_METHOD:-"lz4"}"
WALG_BACKUP_FROM_REPLICA="${WALG_BACKUP_FROM_REPLICA:-"undefined"}"
WALG_DAYS_TO_RETAIN="${WALG_DAYS_TO_RETAIN:-"undefined"}"
SLEEP_COUNTER="${SLEEP_COUNTER:-"undefined"}"
SLEEP_PERIOD="${SLEEP_PERIOD:-"undefined"}"

[ "$PGHOST" = "undefined" ] && echo "PGHOST must be defined" && exit 1
[ "$PGPORT" = "undefined" ] && echo "PGPORT must be defined" && exit 1
[ "$INIT_CONN_DB" = "undefined" ] && echo "INIT_CONN_DB must be defined" && exit 1
[ "$INIT_USER" = "undefined" ] && echo "INIT_USER must be defined" && exit 1
[ "$WALG_S3_PREFIX" = "undefined" ] && echo "WALG_S3_PREFIX must be defined" && exit 1
[ "$WALG_BACKUP_FROM_REPLICA" = "undefined" ] && echo "WALG_BACKUP_FROM_REPLICA must be defined" && exit 1
[ "$WALG_DAYS_TO_RETAIN" = "undefined" ] && echo "WALG_DAYS_TO_RETAIN must be defined" && exit 1
[ "$SLEEP_COUNTER" = "undefined" ] && echo "SLEEP_COUNTER must be defined" && exit 1
[ "$SLEEP_PERIOD" = "undefined" ] && echo "SLEEP_PERIOD must be defined" && exit 1

HOME="/run/postgresql"
WALG_CMD=(
  "su-exec"
  "postgres:postgres"
  "wal-g"
  "--walg-s3-prefix" "$WALG_S3_PREFIX"
  "--walg-compression-method" "$WALG_BACKUP_COMPRESSION_METHOD"
  "--pghost" "$PGHOST"
  "--pgport" "$PGPORT"
)

function log {
  echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") - $0 - $*"
}

# Leave at least 2 days base backups before creating a new one
[[ $WALG_DAYS_TO_RETAIN -lt 2 ]] && WALG_DAYS_TO_RETAIN="2"

if ! id postgres &>/dev/null; then
  echo "Creating container user postgres"
  useradd -m -d "$HOME" -U -u 1500 -c "Postgres Container User" postgres
fi

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
  echo "  PGHOST:                          $PGHOST"
  echo "  PGPORT:                          $PGPORT"
  echo "  PG_NODE:                         $PG_NODE"
  echo "  PGDATA:                          $PGDATA"
  echo "  WALG_S3_PREFIX:                  $WALG_S3_PREFIX"
  echo "  WALG_BACKUP_COMPRESSION_METHOD:  $WALG_BACKUP_COMPRESSION_METHOD"
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
  COUNT=0
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
    ((COUNT = COUNT + 1))
  done < <("${WALG_CMD[@]}" backup-list 2>/dev/null | sed '0,/^name\s*\(last_\)\{0,1\}modified\s*/d')

  # We want to keep at least N days worth of backups
  BACKUPS_PER_DAY="$(printf %.0f "$(echo "86400 / $SLEEP_COUNTER / $SLEEP_PERIOD" | bc -l)")"
  MIN_RETENTION="$((WALG_DAYS_TO_RETAIN * BACKUPS_PER_DAY))"
  echo
  echo "Walg backup statistics:"
  echo "  Backups per day:                 $BACKUPS_PER_DAY"
  echo "  Minimum backup retention:        $MIN_RETENTION"
  echo "  Existing backups counted:        $COUNT"
  echo "  Existing backups to keep:        $LEFT"
  echo "  Existing backups expired:        $((COUNT - LEFT))"

  if [ -n "$BEFORE" ] && [[ $LEFT -ge $MIN_RETENTION ]]; then
    "${WALG_CMD[@]}" delete before FIND_FULL "$BEFORE" --confirm
    echo "  Expired backups deleted:         $((COUNT - LEFT))"
  elif [ -n "$BEFORE" ] && [[ $COUNT -ge $MIN_RETENTION ]]; then
    "${WALG_CMD[@]}" delete retain FULL "$MIN_RETENTION" --confirm
    echo "  Expired backups deleted:         $((COUNT - MIN_RETENTION))"
  else
    echo "  Expired backups deleted:         0"
  fi

  # Push a new base backup
  echo
  log "Producing a new wal-g backup"

  # Reduce the priority of the backup for CPU consumption
  nice -n 5 "${WALG_CMD[@]}" backup-push --full "$PGDATA" --pguser "$INIT_USER" --pgdatabase "$INIT_CONN_DB"
done
