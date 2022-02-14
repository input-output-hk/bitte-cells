{ inputs
, system
}:
# wannabe just tasks for repo-automation, eventually integrated with `just`
let
  packages = inputs.self.packages.${system.host.system};
in
{
  # TODO: script to update materialization:
  # $ nix build .\#cardano-node.passthru.generateMaterialized
  # $ ./result cells/cardano/packages/materialized
  node-2nix = packages.cardano-node.passthru.generateMaterialized;
}
