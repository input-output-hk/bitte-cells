{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  default = nixpkgs.vector;
}
