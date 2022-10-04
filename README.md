# Bitte Cells

A Bitte **Cell** is a domain unit made for [`bitte`][bitte]
deployments that combines the following **Organelles**:

- **Installables**:
  - Packages (`packages`)
- **Runnables**:
  - Entrypoints (`entrypoints`)
- **Functions**:
  - Library (`library`)
  - Nomad Jobs (`nomadJob`)
  - Devshell Profiles (`devshellProfiles`)
  - Nixos Profiles (`nixosProfiles`)
  - Hydration Profiles (`hydrationProfiles`)

You'll find further information about this nomenclature in the
[Standard Readme][std-readme].

## Usage

```nix
# flake.nix
{
  inputs.std.url = "github:divnix/std";

  # use multiple revisions of the same flake to track individual cell's release cycles
  inputs.cardano-cell.url = "github:input-output-hk/bitte-cells/<cardno-cell-revision>";
  inputs.patroni-cell.url = "github:input-output-hk/bitte-cells/<patroni-cell-revision>";

  outputs = inputs: inputs.std.growOn {
    inherit inputs;
    systems = [{
        build = "x86_64-unknown-linux-gnu";  # GNU/Linux 64 bits
        host = "x86_64-unknown-linux-gnu";  # GNU/Linux 64 bits
    }];
    cellsFrom = ./cells;
    cellBlocks = [ "<...>" ];
  }

  # soil
  (inputs.std.harvest "cardano" inputs.cardano-cell)
  (inputs.std.harvest "patroni" inputs.patroni-cell)
  ;
}
```

---

[bitte]: https://github.com/input-output-hk/bitte
[std-readme]: https://github.com/divnix/std#readme
