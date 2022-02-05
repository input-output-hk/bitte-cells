{
    description = "Bitte Cells";
    inputs.std.url = "github:divnix/std";
    outputs = inputs: inputs.std.grow {
        inherit inputs;
        as-nix-cli-epiphyte = false;
        systems = [{
            build = "x86_64-unknown-linux-gnu";  # GNU/Linux 64 bits
            host = "x86_64-unknown-linux-gnu";  # GNU/Linux 64 bits
        }];
        cellsFrom = ./cells;
        organelles = [
            (inputs.std.runnables "entrypoints")
            (inputs.std.installables "packages")
            (inputs.std.functions "library")
            (inputs.std.functions "nomadJob")
            (inputs.std.functions "devshellProfiles")
            (inputs.std.functions "nixosProfiles")
            (inputs.std.functions "hydrationProfiles")
        ];
    };
}
