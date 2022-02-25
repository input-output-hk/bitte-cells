#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

# For the snapshot date, see the s3 metadata tag snapshotDate.

[ -z "${socketPath:-}" ] && echo "socketPath env var must be set -- aborting" && exit 1
[ -z "${envName:-}" ] && echo "envName env var must be set -- aborting" && exit 1
[ -z "${stateDir:-}" ] && echo "stateDir env var must be set -- aborting" && exit 1

stateDir="${stateDir/#\~/$HOME}"

S3_BASE="s3://iog-atala-bitte/shared-artifacts"

mkdir -p "${stateDir}"
S3_PULL() {
  if aws s3 cp "$S3_BASE/db-${envName}.tgz" "${stateDir}/db-${envName}.tgz"; then
    echo "Snapshot file retrieved from s3."
  else
    echo "Snapshot file retreival failed, syncing from genesis."
  fi

  if aws s3 cp "$S3_BASE/db-${envName}.tgz.sha256" "${stateDir}/db-${envName}.tgz.sha256"; then
    echo "Snapshot sha256sum file retrieved from s3."
  else
    echo "Snapshot sha256sum file retreival failed, syncing from genesis."
  fi
}

EXTRACT() {
  cd "${stateDir}"
  if sha256sum -c "db-${envName}.tgz.sha256"; then
    echo "Snapshot sha256 validation passed."
    echo "Extracting snapshot to ${stateDir}."
    if tar -C "${stateDir}" -zxf "${stateDir}/db-${envName}.tgz"; then
      echo "Extracting snapshot to ${stateDir} complete."
      echo "Restore complete."
    else
      echo "Extracting snapshot to ${stateDir} failed."
      echo "Restore failed, syncing from genesis."
    fi
  else
    echo "Snapshot sha256 validation failed, syncing from genesis."
  fi
}

if ! [ -d "${stateDir}/db-${envName}" ]; then
  echo "Cardano node db state not found locally, attempting state snapshot restore."
  if ! [ -s "${stateDir}/db-${envName}.tgz" ]; then
    if S3_PULL; then
      EXTRACT
    fi
  elif [ -s "${stateDir}/db-${envName}.tgz" ] && [ -s "${stateDir}/db-${envName}.tgz.sha256" ]; then
    echo "Utilizing existing restore file: ${stateDir}/db-${envName}.tgz."
    EXTRACT
  fi
else
  echo "Cardano db directory already exists for network: $envName."
fi
