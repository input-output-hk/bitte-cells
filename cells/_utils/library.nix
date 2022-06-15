{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs nix;
  n2c = inputs.n2c.packages.nix2container;
  debug-tools = pkgs:
    with pkgs; [
      coreutils
      inetutils
      findutils
      dnsutils
      ripgrep
      strace
      curl
      gawk
      jq
      fd
    ];
in {
  mkDebugOCI = entrypoint: oci: let
    iog-debug-banner = nixpkgs.runCommandNoCC "iog-debug-banner" {} ''
      ${nixpkgs.figlet}/bin/figlet -f banner "IOG Debug" > $out
    '';
    debug-tools-layer = n2c.buildLayer {deps = debug-tools;};
    debug-bin = nixpkgs.writeShellApplication {
      name = "debug";
      runtimeInputs =
        entrypoint.runtimeInputs
        or []
        ++ entrypoint.debugInputs or []
        ++ debug-tools
        ++ [nixpkgs.bashInteractive];
      text = ''
        # shellcheck source=/dev/null
        # source ${nixpkgs.cacert}/nix-support/setup-hook
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

  mkDevShellImage = {
    pkgs ? nixpkgs,
    extraLayers ? [],
  }: devShell: let
    paths = with pkgs;
      [
        zsh
        direnv
        coreutils
        gnugrep
        gnused
        gawk
        git
        nix.packages.nix
        shadow
        zsh
        bash
        openssh
        util-linux
        devShell
      ]
      ++ extraLayers
      ++ debug-tools pkgs;
  in
    n2c.buildImage {
      name = "registry.ci.iog.io/${devShell.name}";
      maxLayers = 25;
      config.Env = [
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
      contents = [
        (pkgs.runCommandNoCC "mk-root" {} ''
          mkdir -p "$out/etc/nix"

          printf "%s\n" \
            "extra-experimental-features = nix-command flakes" \
            "accept-flake-config = true" \
            > "$out/etc/nix/nix.conf"

          printf "%s\n" \
            "root:x:root:/bin/zsh" \
            "nixbld:x:30000:nixbld1" \
            > "$out/etc/group"

          printf "%s\n" \
            "root:x:0:0:::" \
            "nixbld1:x:30001:30000::" \
            >> "$out/etc/passwd"

          cat > "$out/etc/zshrc" << EOF
          export HOME=/root
          eval "\$(direnv hook zsh)"
          EOF

          touch "$out/etc/os-release"
        '')
        devShell
        (pkgs.buildEnv {
          name = "root";
          inherit paths;
        })
      ];
    };
}
