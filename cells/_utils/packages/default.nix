{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  srvaddr = nixpkgs.callPackage ./srvaddr.nix {};
  norouter = nixpkgs.callPackage (builtins.fetchurl {
    url = "https://raw.githubusercontent.com/NixOS/nixpkgs/8fbe78de26590d172f8b4b047a65449d4ebc5736/pkgs/tools/networking/norouter/default.nix";
    sha256 = "sha256:1hsnpwkmr9vsj76hvjgd6a7ihpn44px2k435ndw87s1ddnj5jp8h";
  }) {};
}
