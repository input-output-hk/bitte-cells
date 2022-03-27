{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  srvaddr = nixpkgs.callPackage ./srvaddr.nix {};
}
