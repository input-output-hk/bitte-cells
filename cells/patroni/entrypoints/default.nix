{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
in {
  patroni = writeShellApplication {
    name = "entrypoint";
    debugInputs = [
      nixpkgs.less
      nixpkgs.awscli2
    ];
    runtimeInputs = [
      nixpkgs.coreutils
      nixpkgs.curl
      nixpkgs.jq
      nixpkgs.postgresql_12
      nixpkgs.ripgrep
      nixpkgs.shadow
      nixpkgs.su-exec
      nixpkgs.wal-g
      nixpkgs.yq-go
      packages.default
      packages.clone-with-walg
      packages.patroni-callback
      packages.restore-command
      packages.walg-restore
    ];
    text = ''
      # Rotation calculation vars
      TIME_LEASE_DURATION="0"
      TIME_ROTATION_OFFSET="0"
      TIME_SPLAY_OFFSET="0"
      TIME_SPLAY_OFFSET_MAX="0"
      TIME_TO_ROTATION="0"
      TIME_TO_SPARE="0"
      TIME_TTL_EXPIRES="0"
      TS_CREATED="0"
      TS_EXPIRES="0"
      TS_NOW="0"
      TS_ROTATION="0"

      PREPARE_FS () {
        [ -z "''${PERSISTENCE_MOUNTPOINT:-}" ] && echo "PERSISTENCE_MOUNTPOINT env var must be set -- aborting" && exit 1

        HOME=/run/postgresql
        PGDATA="$PERSISTENCE_MOUNTPOINT/postgres/patroni"

        useradd -m -d $HOME -U -u 1500 -c "Postgres Container User" postgres

        # This will copy and chmod both postgres and patroni rest API sets of certs

        cp /secrets/tls/*.pem "$HOME/"
        chmod 0600 "$HOME/key.pem"
        chown -R postgres:postgres "$HOME"

        if [ ! -d "/tmp" ]; then
          mkdir /tmp
          chmod 1777 /tmp
        fi

        if [ ! -d "$PGDATA" ]; then
          mkdir -p "$PGDATA"
          chmod -R 0700 "$PERSISTENCE_MOUNTPOINT"
          chown -R postgres:postgres "$PERSISTENCE_MOUNTPOINT"
        fi
      }

      SET_ROTATE_PARAMS () {
        # To override, set these variables names in the job environment to the desired values
        echo "TOKEN_CHECK_INTERVAL  = ''${TOKEN_CHECK_INTERVAL:=10} seconds, the interval duration the token health will be checked at"
        echo "TOKEN_REFRESH_PERCENT = ''${TOKEN_REFRESH_PERCENT:=80} percent, the percent of lease time elapsed which will trigger a rotation"
        echo "TOKEN_SPLAY_PERCENT   = ''${TOKEN_SPLAY_PERCENT:=5} percent, a randomized time from 0 to total lease time to splay the refresh interval by"
        echo "TOKEN_TTL_WARNING     = ''${TOKEN_TTL_WARNING:=300} seconds, a threshold to log a warning at as token TTL approaches expiration"
        echo
      }

      ROTATE_CONSUL_TOKEN () {
        echo
        echo "Setting credentials at $(date --utc --rfc-3339=seconds)"

        # Ensure we don't pull a pre-cached consul patroni token which may already be near expiry:
        if ! curl --silent --fail-with-body "$VAULT_ADDR/agent/v1/cache-clear" -d '{"type":"request_path","value":"/v1/consul/creds/patroni"}' &> /dev/null; then
          echo "WARNING: unable to clear the vault-agent cache of consul patroni tokens at $(date --utc --rfc-3339=seconds)."
        fi

        if CONSUL_JSON=$(curl --silent --fail-with-body --header "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/consul/creds/patroni"); then
          TS_CREATED=$(date +%s)

          # Purposely use a different consul token name to avoid env vs. config file utilization priority conflict.
          CONSUL_TOKEN=$(jq -r '.data.token' <<< "$CONSUL_JSON")

          # By default, lease_duration is the same as max_lease_duration.
          # In the case that it is different, we will still use lease_duration as the token ttl to calculate rotation from.
          TIME_LEASE_DURATION=$(jq -r '.lease_duration' <<< "$CONSUL_JSON")

          # Calculate rotation times
          TIME_ROTATION_OFFSET=$((TIME_LEASE_DURATION * TOKEN_REFRESH_PERCENT / 100))
          TIME_SPLAY_OFFSET_MAX=$((TIME_LEASE_DURATION * TOKEN_SPLAY_PERCENT / 100))
          TIME_SPLAY_OFFSET=$(shuf -i0-$TIME_SPLAY_OFFSET_MAX -n1)
          TS_ROTATION=$((TS_CREATED + TIME_ROTATION_OFFSET - TIME_SPLAY_OFFSET))
          TS_EXPIRES=$((TS_CREATED + TIME_LEASE_DURATION))
          TIME_TO_SPARE=$((TS_EXPIRES - TS_ROTATION))

          # Print debug info
          echo "TS_CREATED = $TS_CREATED timestamp @ $(date --utc --rfc-3339=seconds --date @"$TS_CREATED")"
          echo "TS_ROTATION = $TS_ROTATION timestamp @ $(date --utc --rfc-3339=seconds --date @"$TS_ROTATION")"
          echo "TS_EXPIRES = $TS_EXPIRES timestamp @ $(date --utc --rfc-3339=seconds --date @"$TS_EXPIRES")"
          echo "TIME_LEASE_DURATION = $TIME_LEASE_DURATION seconds"
          echo "TIME_ROTATION_OFFSET = $TIME_ROTATION_OFFSET seconds"
          echo "TIME_SPLAY_OFFSET_MAX = $TIME_SPLAY_OFFSET_MAX seconds"
          echo "TIME_SPLAY_OFFSET = $TIME_SPLAY_OFFSET seconds"
          echo "TIME_TO_SPARE = $TIME_TO_SPARE seconds between rotation and expiry"

          echo "CONSUL_TOKEN: $CONSUL_TOKEN"

          # The patroni env variable of PATRONI_CONSUL_TOKEN would take precedence over the consul token in the patroni configuration file,
          # but because patroni is running as a background task, we can't pass an updated consul env var to it.
          # Instead, we'll substitute the fresh patroni consul token into the patroni configuration file and reload patroni config.
          #
          # Prior approaches to patroni consul token rotation included using a consul template, but this had drawbacks of:
          # a) When the consul token max_lease_ttl was the same as the vault system max_lease_ttl, the rotation did not occur properly;
          # b) When the consul token max_lease_ttl was less than the vault system max_lease_ttl, a full job restart was still required for rotation,
          #    causing the timeline to increment and member instability due to small restart time splay.
          #
          export CONSUL_TOKEN
          yq eval -i '.consul.token = strenv(CONSUL_TOKEN)' /secrets/patroni.yaml

          # Reload patroni configuration files if a pid argument was passed to this function
          if [ "$#" = "1" ]; then
            kill -SIGHUP "$1"
          fi
        else
          TS_NOW=$(date +%s)
          TIME_TTL_EXPIRES=$((TS_EXPIRES - TS_NOW))
          if [ "$TIME_TTL_EXPIRES" -gt "0" ]; then
            echo "WARNING: unable to obtain a new consul token for rotation at $(date --utc --rfc-3339=seconds) with $TIME_TTL_EXPIRES seconds of life remaining."
          else
            echo "WARNING: unable to obtain a new consul token for rotation at $(date --utc --rfc-3339=seconds) with 0 seconds of life remaining."
          fi
        fi
      }

      ROTATE_CONSUL_EVAL () {
        TS_NOW=$(date +%s)
        TIME_TO_ROTATION=$((TS_ROTATION - TS_NOW))
        TIME_TTL_EXPIRES=$((TS_EXPIRES - TS_NOW))

        # Log a warning if token TTL is close to expiring
        if [ "$TIME_TTL_EXPIRES" -lt "$TOKEN_TTL_WARNING" ]; then
          MSG1="WARNING: Consul token remaining TTL is $TIME_TTL_EXPIRES seconds with rotation planned in $TIME_TO_ROTATION seconds;"
          MSG2="it is recommended to maintain at least $TOKEN_TTL_WARNING TTL seconds prior to rotation"
          echo "$MSG1 $MSG2"
        fi

        if [ "$TS_NOW" -gt "$TS_ROTATION" ]; then
          ROTATE_CONSUL_TOKEN "$PATRONI_PID"
        fi
      }

      PREPARE_FS
      SET_ROTATE_PARAMS
      ROTATE_CONSUL_TOKEN

      echo Running patroni in background
      set -m
      trap 'kill $PATRONI_PID' INT
      su-exec postgres:postgres patroni "$@" &
      PATRONI_PID="$!"
      echo "Patroni background PID: $PATRONI_PID"
      echo

      while true; do
        sleep "$TOKEN_CHECK_INTERVAL"
        ROTATE_CONSUL_EVAL
      done
    '';
  };
  patroni-backup-sidecar = writeShellApplication {
    name = "entrypoint";
    text = fileContents ./backup-sidecar-entrypoint.sh;
    runtimeInputs = [
      nixpkgs.coreutils
      nixpkgs.su-exec
      nixpkgs.shadow
      nixpkgs.bc
      nixpkgs.gnused
      nixpkgs.postgresql_12
      nixpkgs.wal-g
    ];
  };
}
