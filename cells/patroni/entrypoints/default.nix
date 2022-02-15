{ inputs
, system
}:
let
  packages = inputs.self.packages.${system.build.system};
  library = inputs.self.library.${system.build.system};
  nixpkgs = inputs.nixpkgs;
  writeShellApplication = library._writers-writeShellApplication;
  fileContents = nixpkgs.lib.strings.fileContents;
in
{
  entrypoint = nixpkgs.symlinkJoin {
    name = "patroni-entrypoint";
    paths = [
      (
        writeShellApplication {
          name = "patroni-entrypoint";
          text = (fileContents ./entrypoint.sh);
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
    text = (fileContents ./backup-sidecar-entrypoint.sh);
    runtimeInputs = [ nixpkgs.coreutils nixpkgs.postgresql_12 nixpkgs.wal-g ];
  };
}
