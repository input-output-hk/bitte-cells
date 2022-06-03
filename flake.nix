{
  description = "Bitte Cells";
  inputs = {
    std.url = "github:divnix/std";
    n2c.url = "github:nlewo/nix2container";
    data-merge.url = "github:divnix/data-merge";
    cicero.url = "github:input-output-hk/cicero";
  };

  outputs = {
    std,
    cicero,
    nixpkgs,
    ...
  } @ inputs:
    (std.grow {
      inherit inputs;
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      cellsFrom = ./cells;
      organelles = [
        (std.runnables "healthChecks")
        (std.runnables "entrypoints")
        # just repo automation; std - just integration pending
        (std.runnables "justTasks")
        (std.installables "oci-images")
        (std.installables "packages")
        (std.functions "library")
        (std.data "constants")
        (std.functions "nomadJob")
        (std.functions "nomadTask")
        (std.functions "nomadFragments")
        (std.functions "devshellProfiles")
        (std.functions "nixosProfiles")
        (std.functions "hydrationProfiles")
      ];
    })
    // {
      ciceroActions =
        cicero.lib.callActionsWithExtraArgs
        rec {
          inherit (cicero.lib) std;
          inherit (nixpkgs) lib;
          actionLib = import "${cicero}/action-lib.nix" {inherit std lib;};
        }
        cicero/actions;
    };
}
