{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.cells._writers.library) writeShellApplication;
  inherit (cell) packages;
in {
  patroni-state-running = writeShellApplication {
    runtimeInputs = [nixpkgs.jq nixpkgs.coreutils nixpkgs.curl];
    name = "healthcheck";
    text = ''
      [ -z "''${NOMAD_PORT_patroni:-}" ] && echo "NOMAD_PORT_patroni env var must be set -- aborting" && exit 1

      STATUS="$(curl -sk "https://localhost:$NOMAD_PORT_patroni/" || :)"
      jq <<< "$STATUS" || :
      jq -e '.state == "running"' <<< "$STATUS" &> /dev/null || exit 2
    '';
  };
}
