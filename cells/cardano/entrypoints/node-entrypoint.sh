#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

# For the snapshot date, see the s3 metadata tag snapshotDate.

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${envName:-}" ] && echo "envName env var must be set -- aborting" && exit 1
[ -z "${stateDir:-}" ] && echo "stateDir env var must be set -- aborting" && exit 1

S3_BASE="s3://iog-atala-bitte/shared-artifacts"
RESTORE_DIR="${stateDir}"
LOCAL_DB_FILE="$RESTORE_DIR/db-${envName}.tgz"
RESTORE_DB_FILE="$S3_BASE/db-${envName}.tgz"

S3_PULL() {
  if aws s3 cp "$RESTORE_DB_FILE" "$RESTORE_DIR"; then
    echo "Snapshot file retrieved from s3."
  else
    echo "Snapshot file retreival failed, syncing from genesis."
  fi

  if aws s3 cp "$RESTORE_DB_FILE.sha256" "$RESTORE_DIR"; then
    echo "Snapshot sha256sum file retrieved from s3."
  else
    echo "Snapshot sha256sum file retreival failed, syncing from genesis."
  fi
}

EXTRACT() {
  cd "$RESTORE_DIR"
  if sha256sum -c "$LOCAL_DB_FILE.sha256"; then
    echo "Snapshot sha256 validation passed."
    echo "Extracting snapshot to $RESTORE_DIR."
    if tar -C "$RESTORE_DIR" -zxf "$LOCAL_DB_FILE"; then
      echo "Extracting snapshot to $RESTORE_DIR complete."
      echo "Restore complete."
    else
      echo "Extracting snapshot to $RESTORE_DIR failed."
      echo "Restore failed, syncing from genesis."
    fi
  else
    echo "Snapshot sha256 validation failed, syncing from genesis."
  fi
}

if ! [ -d "$RESTORE_DIR/db-$envName" ]; then
  echo "Cardano node db state not found locally, attempting state snapshot restore."
  if ! [ -s "$LOCAL_DB_FILE" ]; then
    if S3_PULL; then
      EXTRACT
    fi
  elif [ -s "$LOCAL_DB_FILE" ] && [ -s "$LOCAL_DB_FILE.sha256" ]; then
    echo "Utilizing existing restore file: $LOCAL_DB_FILE."
    EXTRACT
  fi
else
  echo "Cardano db directory already exists for network: $envName."
fi

mkdir -p "${socketPath}"
