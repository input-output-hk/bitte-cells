{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) packages;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
in {
  entrypoint = nixpkgs.symlinkJoin {
    name = "patroni-symlinks";
    paths = [
      (
        writeShellApplication {
          name = "patroni-entrypoint";
          text = fileContents ./entrypoint.sh;
          runtimeInputs = [
            nixpkgs.coreutils
            nixpkgs.postgresql_12
            nixpkgs.wal-g
            packages.patroni
            packages.patroni-clone-with-walg
            packages.patroni-callback
            packages.patroni-restore-command
            packages.patroni-walg-restore
          ];
        }
      )
      # fix for popen failure: Cannot allocate memory
      # through `nix profile install`, this provides /bin/sh which is a hard-coded dependency of some postgres commands
      nixpkgs.bashInteractive
    ];
  };
  backup-sidecar-entrypoint = writeShellApplication {
    name = "patroni-backup-sidecar-entrypoint";
    text = fileContents ./backup-sidecar-entrypoint.sh;
    runtimeInputs = [nixpkgs.coreutils nixpkgs.postgresql_12 nixpkgs.wal-g];
  };
}
