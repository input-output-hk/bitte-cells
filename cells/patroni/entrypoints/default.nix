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
  entrypoint = writeShellApplication {
    name = "patroni-entrypoint";
    text = (fileContents ./entrypoint.sh);
    runtimeInputs = [
      nixpkgs.coreutils
      nixpkgs.postgresql_12
      packages.patroni
      packages.patroni-clone-with-walg
      packages.patroni-callback
      packages.patroni-restore-command
      packages.patroni-walg-restore
    ];
  };
  backup-sidecar-entrypoint = writeShellApplication {
    name = "patroni-backup-sidecar-entrypoint";
    text = (fileContents ./backup-sidecar-entrypoint.sh);
    runtimeInputs = [ nixpkgs.coreutils nixpkgs.postgresql_12 nixpkgs.wal-g ];
  };
}
