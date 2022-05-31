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
      nixpkgs.su-exec
      nixpkgs.shadow
      nixpkgs.postgresql_12
      nixpkgs.wal-g
      packages.default
      packages.clone-with-walg
      packages.patroni-callback
      packages.restore-command
      packages.walg-restore
    ];
    text = ''

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

      echo
      echo "Starting postgres patroni high availability job"

      su-exec postgres:postgres patroni "$@"
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
