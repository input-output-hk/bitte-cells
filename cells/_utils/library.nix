{ inputs, cell}: let
  inherit (inputs) nixpkgs;
in {
  mkDebugOCI = entrypoint: oci: let
    iog-debug-banner = nixpkgs.runCommandNoCC "iog-debug-banner" {} ''
      ${nixpkgs.figlet}/bin/figlet -f banner "IOG Debug" > $out
    '';
    debug-bin = nixpkgs.writeShellApplication {
      name = "debug";
      runtimeInputs = entrypoint.runtimeInputs ++ entrypoint.debugInputs;
      text = ''
        ${nixpkgs.coreutils}/bin/cat ${iog-debug-banner}
        exec bash "$@"
      '';
    };
  in
    oci
    // {
      contents = oci.contents ++ [debug-bin];
    };
}
