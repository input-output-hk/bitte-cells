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
      nixpkgs.strace
    ];
    runtimeInputs = [
      nixpkgs.coreutils
      nixpkgs.curl
      nixpkgs.jq
      nixpkgs.postgresql_12
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
      # Rotation related vars
      TEMPLATE_CHECK="0"
      TEMPLATE_HASH="0"
      TIME_LEASE_DURATION="0"
      TIME_ROTATION_OFFSET="0"
      TIME_SPLAY_OFFSET="0"
      TIME_SPLAY_OFFSET_MAX="0"
      TIME_TO_ROTATION="0"
      TIME_TO_SPARE="0"
      TIME_TTL_EXPIRES="0"
      TS_CONSUL="0"
      TS_CREATED="0"
      TS_DELTA="0"
      TS_EXPIRES="0"
      TS_NOW="0"
      TS_ROTATION="0"
      TS_VAULT="0"

      PREPARE_FS () {
        [ -z "''${VAULT_ADDR:-}" ] && echo "VAULT_ADDR env var must be set -- aborting" && exit 1
        [ -z "''${CONSUL_HTTP_ADDR:-}" ] && echo "CONSUL_HTTP_ADDR env var must be set -- aborting" && exit 1
        [ -z "''${PERSISTENCE_MOUNTPOINT:-}" ] && echo "PERSISTENCE_MOUNTPOINT env var must be set -- aborting" && exit 1

        HOME=/run/postgresql
        PGDATA="$PERSISTENCE_MOUNTPOINT/postgres/patroni"

        useradd -m -d $HOME -U -u 1500 -c "Postgres Container User" postgres

        # This will copy and chmod both postgres and patroni rest API sets of certs.
        # Further PKI cert rotation during runtime will be triggered by consul template change_mode signal via SIGHUP.
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
        # To override, set these variables names in the job environment to the desired values.
        echo "TEMPLATE_FILE         = ''${TEMPLATE_FILE:=/secrets/patroni.yaml-template}, the full path to the patroni config template to substitute with rotated consul tokens"
        echo "TOKEN_CHECK_INTERVAL  = ''${TOKEN_CHECK_INTERVAL:=10} seconds, the interval duration the token health will be checked at"
        echo "TOKEN_DELTA_WARNING   = ''${TOKEN_DELTA_WARNING:=10} seconds, a threshold to log a warning if the consul token timestamp and vault lease API timestamp differ by a significant amount"
        echo "TOKEN_REFRESH_PERCENT = ''${TOKEN_REFRESH_PERCENT:=80} percent, the percent of lease time elapsed which will trigger a rotation"
        echo "TOKEN_SPLAY_PERCENT   = ''${TOKEN_SPLAY_PERCENT:=5} percent, a randomized time from 0 to total lease time to splay the refresh interval by"
        echo "TOKEN_TTL_WARNING     = ''${TOKEN_TTL_WARNING:=300} seconds, a threshold to log a warning at as token TTL approaches expiration"
      }

      ROTATE_CONSUL_TOKEN () {
        echo
        echo "Setting credentials at $(date --utc --rfc-3339=seconds)"

        # Ensure we don't pull a pre-cached consul patroni token which may already be near expiry:
        if ! curl --silent --fail-with-body "$VAULT_ADDR/agent/v1/cache-clear" -d '{"type":"request_path","value":"/v1/consul/creds/patroni"}' &> /dev/null; then
          echo "WARNING: unable to clear the vault-agent cache of consul patroni tokens at $(date --utc --rfc-3339=seconds)."
        fi

        if VAULT_JSON=$(curl --silent --fail-with-body --header "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/consul/creds/patroni"); then
          TS_VAULT=$(date +%s)

          # Purposely use a different consul token name to avoid env vs. config file utilization priority conflict.
          CONSUL_TOKEN=$(jq -r '.data.token' <<< "$VAULT_JSON")
          CONSUL_ACCESSOR=$(jq -r '.data.accessor' <<< "$VAULT_JSON")

          # By default, lease_duration is the same as max_lease_duration.
          # In the case that it is different, we will still use lease_duration as the token ttl to calculate rotation from.
          TIME_LEASE_DURATION=$(jq -r '.lease_duration' <<< "$VAULT_JSON")

          # The consul token request response obtained from vault contains a lease length, but not a creation timestamp.
          # We check the actual consul token creation timestamp to ensure we somehow haven't gotten an aged token due to vault-agent caching or some other mechanism.
          # To be conservative, we utilize the oldest timestamp between consul reported token creation and vault API call timestamp to avoid edge cases,
          # for example system times between machines being out of sync, and produce a warning if the vault vs consul timestamp delta is unexpectedly large.
          if CONSUL_JSON=$(curl --silent --fail-with-body --header "X-CONSUL-TOKEN: $CONSUL_TOKEN" "$CONSUL_HTTP_ADDR/v1/acl/token/self"); then
            TS_CONSUL=$(date --date "$(jq -r '.CreateTime' <<< "$CONSUL_JSON")" +%s)
            TS_DELTA=$((TS_CONSUL - TS_VAULT))
            if [ "''${TS_DELTA#-}" -gt "$TOKEN_DELTA_WARNING" ]; then
              echo "WARNING: the time delta between consul token creation @ $(date --utc --rfc-3339=seconds --date @"$TS_CONSUL") and vault consul token lease request is unexpectedly large at $TS_DELTA seconds."
            fi

            if [ "$TS_CONSUL" -le "$TS_VAULT" ]; then
              TS_CREATED="$TS_CONSUL"
            else
              TS_CREATED="$TS_VAULT"
            fi
          else
            echo "WARNING: unable to obtain a creation time for the vault returned consul token."
            TS_CREATED="$TS_VAULT"
          fi

          # Calculate rotation times
          TIME_ROTATION_OFFSET=$((TIME_LEASE_DURATION * TOKEN_REFRESH_PERCENT / 100))
          TIME_SPLAY_OFFSET_MAX=$((TIME_LEASE_DURATION * TOKEN_SPLAY_PERCENT / 100))
          TIME_SPLAY_OFFSET=$(shuf -i0-$TIME_SPLAY_OFFSET_MAX -n1)
          TS_ROTATION=$((TS_CREATED + TIME_ROTATION_OFFSET - TIME_SPLAY_OFFSET))
          TS_EXPIRES=$((TS_CREATED + TIME_LEASE_DURATION))
          TIME_TO_SPARE=$((TS_EXPIRES - TS_ROTATION))

          # The patroni env variable of PATRONI_CONSUL_TOKEN would take precedence over the consul token in the patroni configuration file,
          # but because patroni is running as a background task, we can't pass an updated consul env var to it.
          # Instead, we'll substitute the fresh patroni consul token into the patroni configuration file and reload patroni config.
          #
          # Prior approaches to patroni consul token rotation included using a consul template, but this had drawbacks of:
          # a) When the consul token max_lease_ttl was the same as the vault system max_lease_ttl, the rotation did not occur properly;
          # b) When the consul token max_lease_ttl was less than the vault system max_lease_ttl, a full job restart was still required for rotation,
          #    causing the timeline to increment and member instability due to small restart time splay.
          #
          # Here we cannot token substitute directly into the original consul template without problems because within seconds to minutes after
          # substitution the template file will be replaced by consul with the original template and our rotated token substitution lost, even if the
          # template change_mode is `noop`.
          #
          # Rather we will leave the original template untouched as a template named file and substitute a copied template file.
          export CONSUL_TOKEN
          yq eval '.consul.token = strenv(CONSUL_TOKEN)' $TEMPLATE_FILE > /secrets/patroni.yaml

          # The original template file will be watched for checksum changes so the substituted file stays current.
          TEMPLATE_HASH=$(sha256sum $TEMPLATE_FILE)

          # Print helpful rotation info
          echo "INFO: TS_CREATED = $TS_CREATED timestamp @ $(date --utc --rfc-3339=seconds --date @"$TS_CREATED")"
          echo "INFO: TS_ROTATION = $TS_ROTATION timestamp @ $(date --utc --rfc-3339=seconds --date @"$TS_ROTATION")"
          echo "INFO: TS_EXPIRES = $TS_EXPIRES timestamp @ $(date --utc --rfc-3339=seconds --date @"$TS_EXPIRES")"
          echo "INFO: TIME_LEASE_DURATION = $TIME_LEASE_DURATION seconds"
          echo "INFO: TIME_ROTATION_OFFSET = $TIME_ROTATION_OFFSET seconds"
          echo "INFO: TIME_SPLAY_OFFSET_MAX = $TIME_SPLAY_OFFSET_MAX seconds"
          echo "INFO: TIME_SPLAY_OFFSET = $TIME_SPLAY_OFFSET seconds"
          echo "INFO: TIME_TO_SPARE = $TIME_TO_SPARE seconds between rotation and expiry"
          echo "INFO: TEMPLATE_HASH = ''${TEMPLATE_HASH%% *}"
          echo "INFO: CONSUL_ACCESSOR: $CONSUL_ACCESSOR"

          # Reload patroni configuration files if a pid argument was passed to this function so that patroni starts using the newly rotated token.
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

      TEMPLATE_CHECK_FOR_CHANGE () {
        TEMPLATE_CHECK=$(sha256sum $TEMPLATE_FILE)
        if [ "$TEMPLATE_CHECK" != "$TEMPLATE_HASH" ]; then
          echo
          echo "INFO: Patroni template file $TEMPLATE_FILE has changed; re-substituting the current consul token and reloading patroni and postgres"
          echo "INFO: Previous patroni template hash: ''${TEMPLATE_HASH%% *}"
          echo "INFO: Current patroni template hash:  ''${TEMPLATE_CHECK%% *}"
          echo "INFO: Current consul token accessor:  $CONSUL_ACCESSOR"
          yq eval '.consul.token = strenv(CONSUL_TOKEN)' $TEMPLATE_FILE > /secrets/patroni.yaml
          TEMPLATE_HASH="$TEMPLATE_CHECK"
          kill -SIGHUP "$PATRONI_PID"
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
        else
          TEMPLATE_CHECK_FOR_CHANGE
        fi
      }

      ROTATE_PKI () {
        # Consul template will issue a SIGHUP to the patroni job when PKI is rotated
        cp /secrets/tls/*.pem "$HOME/"
        chmod 0600 "$HOME/key.pem"
        chown -R postgres:postgres "$HOME"

        # Reload patroni configuration files if a pid argument was passed to this function.
        # This will also cause a postgres hot reload via SIGHUP from patroni to postgres via the callback script.
        if [ "$#" = "1" ]; then
          kill -SIGHUP "$1"
        fi
      }

      PREPARE_FS
      SET_ROTATE_PARAMS
      ROTATE_CONSUL_TOKEN

      echo "INFO: Running patroni in background"
      set -m

      trap 'kill $PATRONI_PID' INT
      trap 'ROTATE_PKI $PATRONI_PID' HUP

      su-exec postgres:postgres patroni "$@" &
      PATRONI_PID="$!"
      echo "INFO: Patroni background PID: $PATRONI_PID"
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
