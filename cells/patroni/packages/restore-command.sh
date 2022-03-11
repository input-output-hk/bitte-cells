#! /usr/env bash

# Credit for the majority of code in this script goes to the spilo project:
# Ref: https://github.com/zalando/spilo/blob/master/postgres-appliance/scripts/restore_command.sh
#
readonly wal_filename=$1
readonly wal_destination=$2

[[ -z ${wal_filename-} || -z ${wal_destination-} ]] && echo "Aborting restore-command -- wal filename or destination missing" && exit 1

echo "Running restore-command $wal_filename $wal_destination..."
wal_dir=$(dirname "$wal_destination")
readonly wal_dir
wal_fast_source=$(dirname "$(dirname "$(realpath "$wal_dir")")")/wal_fast/$wal_filename
readonly wal_fast_source

[[ -f $wal_fast_source ]] && echo "Restore-command -- moving wal_fast_source" && exec mv "${wal_fast_source}" "${wal_destination}"

# Patroni fetching missing files for pg_rewind
if [[ $wal_destination =~ /$wal_filename$ ]]; then
  export WALG_DOWNLOAD_CONCURRENCY=1
fi

wal-g wal-fetch "${wal_filename}" "${wal_destination}"
exit 0
