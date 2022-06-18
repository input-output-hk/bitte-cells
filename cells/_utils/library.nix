{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  n2c = inputs.n2c.packages.nix2container;
in {
  mkDebugOCI = with nixpkgs.pkgsStatic;
    entrypoint: oci: let
      iog-debug-banner = runCommandNoCC "iog-debug-banner" {} ''
        ${figlet}/bin/figlet -f banner "IOG Debug" > $out
      '';
      debug-tools = [
        bashInteractive.out
        busybox
        curl.bin
        jq.bin
      ];
      debug-bin = writeShellApplication {
        name = "debug";
        runtimeInputs =
          entrypoint.runtimeInputs
          or []
          ++ entrypoint.debugInputs or []
          ++ debug-tools;
        text = with nixpkgs.pkgsStatic; ''
          # shellcheck source=/dev/null
          # source ''${cacert}/nix-support/setup-hook

          cat ${iog-debug-banner}
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
        contents = (oci.contents or []) ++ [debug-bin];
      };
}
