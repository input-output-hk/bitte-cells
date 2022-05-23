{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.nixpkgs.lib.strings) fileContents;
  inherit
    (inputs.cells._writers.library)
    writeShellApplication
    writePython3Application
    ;
in {
  default = nixpkgs.callPackage ./patroni.nix {};
  clone-with-walg = writePython3Application {
    name = "clone";
    text = fileContents ./clone-with-walg.py;
    libraries = [nixpkgs.python3Packages.dateutil];
  };
  patroni-callback = writeShellApplication {
    name = "call";
    text = fileContents ./callback.sh;
    runtimeInputs = [nixpkgs.postgresql_12];
  };
  restore-command = writeShellApplication {
    name = "restore";
    text = fileContents ./restore-command.sh;
    runtimeInputs = [nixpkgs.wal-g];
  };
  walg-restore = writeShellApplication {
    name = "restore";
    text = fileContents ./walg-restore.sh;
    runtimeInputs = [nixpkgs.findutils nixpkgs.gnused nixpkgs.gawk nixpkgs.wal-g];
  };
}
