{
  inputs,
  cell,
}: let
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
        echo
        echo "=========================================================="
        echo "This debug shell contains the runtime environment and "
        echo "debug dependencies of the entrypoint."
        echo "To inspect the entrypoint(s) run:"
        echo "cat ${entrypoint}/bin/*"
        echo "=========================================================="
        echo
        exec bash "$@"
      '';
    };
  in
    oci
    // {
      contents = oci.contents ++ [debug-bin];
    };
}
