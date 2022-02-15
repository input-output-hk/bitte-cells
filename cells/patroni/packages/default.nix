{ inputs
, system
}:
let
  library = inputs.self.library.${system.build.system};
  nixpkgs = inputs.nixpkgs;
  writeShellApplication = library._writers-writeShellApplication;
  writePython3Application = library._writers-writePython3Application;
  fileContents = nixpkgs.lib.strings.fileContents;
in
{
  "" = nixpkgs.callPackage ./patroni.nix { };
  clone-with-walg = writePython3Application {
    name = "clone-with-walg";
    text = (fileContents ./clone-with-walg.py);
    libraries = [ inputs.nixpkgs.python3Packages.dateutil ];
  };
  callback = writeShellApplication {
    name = "patroni-callback";
    text = (fileContents ./callback.sh);
    runtimeInputs = [ ];
  };
  restore-command = writeShellApplication {
    name = "restore-command";
    text = (fileContents ./restore-command.sh);
    runtimeInputs = [ ];
  };
  walg-restore = writeShellApplication {
    name = "walg-restore";
    text = (fileContents ./walg-restore.sh);
    runtimeInputs = [ nixpkgs.gnused nixpkgs.gawk nixpkgs.wal-g ];
  };
}
