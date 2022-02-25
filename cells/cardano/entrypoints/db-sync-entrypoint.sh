#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting\nMigration logs (if any):\n$(cat /tmp/*.log)" && exit 0' INT

# FIXME: clean-up once https://github.com/hashicorp/nomad/issues/5020#issuecomment-1023140860
# is implemented in nomad
# also clean up: nomadJob/default.nix
# Own the file and set permissons
cp "${PGPASSFILE}" "${PGPASSFILE}.permissioned"
chmod 600 "${PGPASSFILE}.permissioned"
export PGPASSFILE="${PGPASSFILE}.permissioned"

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${stateDir:-}" ] && echo "stateDir env var must be set -- aborting" && exit 1
[ -z "${envFlag:-}" ] && echo "envFlag env var must be set -- aborting" && exit 1
[ -z "${snapShotUrl:-}" ] && echo "snapShotUrl env var must be set -- aborting" && exit 1
[ -z "${snapShotSha:-}" ] && echo "snapShotSha env var must be set -- aborting" && exit 1

mapfile -t envFlag <<<"${envFlag}"

function restore_snapshot {
  mkdir -p "${stateDir}"
  file_count=$(find "${stateDir}" -type f -name '*.lstate' | wc -l)
  if test "${file_count}" -gt 0; then
    echo "Ledger state directory (${stateDir}) is not empty. Don't restore from snapshot."
    return
  fi

  echo "Restoring snapshot from ${snapShotUrl}"
  curl -LOC - "${snapShotUrl}"
  curl -LO "${snapShotUrl}.sha256sum"
  echo "Validating checksum of snapshot"
  sha256sum -c "$(basename "${snapShotUrl}").sha256sum"

  tmp_dir=$(mktemp --directory -t db-sync-snapshot-XXXXXXXXXX)
  echo "Extracting snapshot"
  tar -zxvf "$(basename "${snapShotUrl}")" --directory "$tmp_dir"
  db_file=$(find "$tmp_dir/" -iname "*.sql")
  lstate_file=$(find "${tmp_dir}/" -iname "*.lstate")
  echo "Restoring db-sync ledger state file"
  mv "${lstate_file}" "${stateDir}"
  echo "Restoring database"
  DBNAME="$(cut -d ":" -f 3 "${PGPASSFILE}")"
  DBUSER="$(cut -d ":" -f 4 "${PGPASSFILE}")"
  DBHOST="$(cut -d ":" -f 1 "${PGPASSFILE}")"
  psql -U "${DBUSER}" -h "${DBHOST}" "${DBNAME}" -f "${db_file}"
  rm --recursive "${tmp_dir}"
}

restore_snapshot

until [ -S "${socketPath}" ]; do
  echo "Waiting 10 seconds for cardano-node socket file at ${socketPath}..."
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
  --socket-path "${socketPath}"
  --schema-dir "${schemaDir}"
  --state-dir "${stateDir}"
)
exec "${cmd[@]}"
