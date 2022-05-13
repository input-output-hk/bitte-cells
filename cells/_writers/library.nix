{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit
    (inputs.nixpkgs)
    lib
    stdenv
    writeTextFile
    runtimeShell
    shellcheck
    glibcLocales
    ;
  /*
   * Similar to writeShellScriptBin and writeScriptBin.
   * Writes an executable Shell script to /nix/store/<store path>/bin/<name> and
   * checks its syntax with shellcheck and the shell's -n option.
   * Automatically includes sane set of shellopts (errexit, nounset, pipefail)
   * and handles creation of PATH based on runtimeInputs
   *
   * Note that the checkPhase uses stdenv.shell for the test run of the script,
   * while the generated shebang uses runtimeShell. If, for whatever reason,
   * those were to mismatch you might lose fidelity in the default checks.
   *
   * Example:
   * # Writes my-file to /nix/store/<store path>/bin/my-file and makes executable.
   * writeShellApplication {
   *   name = "my-file";
   *   runtimeInputs = [ curl w3m ];
   *   text = ''
   *     curl -s 'https://nixos.org' | w3m -dump -T text/html
   *    '';
   * }
   */
  writeShellApplication = {
    name,
    text,
    env ? {},
    runtimeInputs ? [],
    checkPhase ? null,
  }:
    writeTextFile {
      inherit name;
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!${runtimeShell}
        set -o errexit
        set -o nounset
        set -o pipefail

        export PATH="${lib.makeBinPath runtimeInputs}:$PATH"
        [ -n "''${DEBUG_SLEEP:-}" ] && sleep "$DEBUG_SLEEP"


        # TODO: cleanup after https://github.com/divnix/std/issues/27
        ${
          builtins.concatStringsSep "\n" (
            lib.attrsets.mapAttrsToList (n: v: "export ${n}=${''"$''}{${n}:-${toString v}}${''"''}")
            env
          )
        }

        ${text}
      '';
      checkPhase =
        if checkPhase == null
        then ''
          runHook preCheck
          ${stdenv.shell} -n $out/bin/${name}
          ${shellcheck}/bin/shellcheck $out/bin/${name}
          runHook postCheck
        ''
        else checkPhase;
      meta.mainProgram = name;
    }
    // {inherit runtimeInputs;};
  writePython3Application = {
    name,
    text,
    env ? {},
    runtimeInputs ? [],
    libraries ? [],
    checkPhase ? null,
  }:
    writeTextFile {
      inherit name;
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!${
          if libraries == []
          then "${nixpkgs.python3}/bin/python"
          else "${nixpkgs.python3.withPackages (ps: libraries)}/bin/python"
        }
        # fmt: off
        import os; os.environ["PATH"] += os.pathsep + os.pathsep.join("${
          lib.makeBinPath runtimeInputs
        }".split(":"))
        import time; time.sleep(os.environ.get("DEBUG_SLEEP", 0))
        ${
          builtins.concatStringsSep "\n" (
            lib.attrsets.mapAttrsToList (n: v: "os.environ['${n}'] = os.environ.get('${n}', '${v}')")
            env
          )
        }
        # fmt: on

        ${text}
      '';
      checkPhase =
        if checkPhase == null
        then ''
          runHook preCheck
          ${nixpkgs.python3Packages.black}/bin/black --check $out/bin/${name}
          runHook postCheck
        ''
        else checkPhase;
      meta.mainProgram = name;
    }
    // {inherit runtimeInputs;};
in {
  inherit writePython3Application;
  writeShellApplication = {...} @ args:
    writeShellApplication (
      args
      // {
        text = ''
          export LOCALE_ARCHIVE=${
            glibcLocales.override {allLocales = false;}
          }/lib/locale/locale-archive
          ${args.text}
        '';
      }
    );
}
