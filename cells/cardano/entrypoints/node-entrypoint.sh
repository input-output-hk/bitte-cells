#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT


# For the snapshot date, see the s3 metadata tag snapshotDate.

[ -z "${CARDANO_NODE_NETWORK:-}" ] && echo "CARDANO_NODE_NETWORK env var must be set -- aborting" && exit 1
[ -z "${CARDANO_NODE_SOCKET_PATH:-}" ] && echo "CARDANO_NODE_SOCKET_PATH env var must be set -- aborting" && exit 1
[ -z "${CARDANO_NODE_STATE_DIR:-}" ] && echo "CARDANO_NODE_STATE_DIR env var must be set -- aborting" && exit 1

RESTORE_DIR="$CARDANO_NODE_STATE_DIR"
S3_BASE="s3://iog-atala-bitte/shared-artifacts"

if [ "$CARDANO_NODE_NETWORK" = "testnet" ]; then
  LOCAL_DB_FILE="$RESTORE_DIR/db-testnet.tgz"
  RESTORE_DB_FILE="$S3_BASE/db-testnet.tgz"
elif [ "$CARDANO_NODE_NETWORK" = "mainnet" ]; then
  LOCAL_DB_FILE="$RESTORE_DIR/db-mainnet.tgz"
  RESTORE_DB_FILE="$S3_BASE/db-mainnet.tgz"
else
  echo "CARDANO_NODE_NETWORK is not a recognized network: $CARDANO_NODE_NETWORK -- aborting"
  exit 1
fi

S3_PULL () {
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

EXTRACT () {
  cd $RESTORE_DIR
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

if ! [ -d "$RESTORE_DIR/db-$CARDANO_NODE_NETWORK" ]; then
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
  echo "Cardano db directory already exists for network: $CARDANO_NODE_NETWORK."
fi

mkdir -p "$CARDANO_NODE_SOCKET_PATH"

