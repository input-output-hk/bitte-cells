{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  n2c = inputs.n2c.packages.nix2container;
in {
  mkDebugOCI = entrypoint: oci: let
    iog-debug-banner = nixpkgs.runCommandNoCC "iog-debug-banner" {} ''
      ${nixpkgs.figlet}/bin/figlet -f banner "IOG Debug" > $out
    '';
    debug-tools = [
      nixpkgs.bashInteractive
      nixpkgs.coreutils
      nixpkgs.inetutils
      nixpkgs.findutils
      nixpkgs.dnsutils
      nixpkgs.ripgrep
      nixpkgs.strace
      nixpkgs.curl
      nixpkgs.gawk
      nixpkgs.jq
      nixpkgs.fd
      nixpkgs.cacert
    ];
    debug-tools-layer = n2c.buildLayer {deps = debug-tools;};
    debug-bin = nixpkgs.writeShellApplication {
      name = "debug";
      runtimeInputs =
        entrypoint.runtimeInputs
        or []
        ++ entrypoint.debugInputs or []
        ++ debug-tools;
      text = ''
        # shellcheck source=/dev/null
        source ${nixpkgs.cacert}/nix-support/setup-hook
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
      contents = oci.contents ++ [debug-bin];
    };
}
