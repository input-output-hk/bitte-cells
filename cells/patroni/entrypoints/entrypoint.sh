#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

mkdir -p /run/postgresql
mkdir -p "$PGDATA"
chmod 0700 "$PGDATA"

# Cannot use direct link and SIGHUP for consul template cert refresh yet due to required ownership change
# Ref: https://github.com/hashicorp/nomad/issues/5020#issuecomment-8228130620
#
# ln -sfn /secrets/{cert,cert-key,cert-ca}.pem "$PGDATA/"

# This will copy and chmod both postgres and patroni rest API sets of certs
cp /secrets/tls/*.pem "/persist-db/postgres/"
chmod 600 "/persist-db/postgres/key.pem"

echo
echo "Starting postgres patroni high availability job"

exec patroni "$@"
