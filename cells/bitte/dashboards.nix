{
  inputs,
  cell,
}: let
  # Since dashboards will exist as either JSON already, or will
  # be converted to JSON from Nix (ex: Grafonnix), dashboard attrs
  # are expected to have values of JSON strings.
  importAsJson = file: builtins.readFile file;
  # importGrafonnixToJson = ...;
in {
  bitte-consul = importAsJson ./dashboards/bitte-consul.json;
  bitte-log = importAsJson ./dashboards/bitte-log.json;
  bitte-loki = importAsJson ./dashboards/bitte-loki.json;
  bitte-nomad = importAsJson ./dashboards/bitte-nomad.json;
  bitte-system = importAsJson ./dashboards/bitte-system.json;
  bitte-tempo-operational = importAsJson ./dashboards/bitte-tempo-operational.json;
  bitte-tempo-reads = importAsJson ./dashboards/bitte-tempo-reads.json;
  bitte-tempo-writes = importAsJson ./dashboards/bitte-tempo-writes.json;
  bitte-traefik = importAsJson ./dashboards/bitte-traefik.json;
  bitte-vault = importAsJson ./dashboards/bitte-vault.json;
  bitte-vmagent = importAsJson ./dashboards/bitte-vmagent.json;
  bitte-vmalert = importAsJson ./dashboards/bitte-vmalert.json;
  bitte-vm = importAsJson ./dashboards/bitte-vm.json;
  bitte-vulnix = importAsJson ./dashboards/bitte-vulnix.json;

  # Upstream dashboards can be imported here, instead of directly
  # imported in the hydrationProfile.  This will allow easier
  # re-export of repo related dashboards which might have downstream
  # re-use.
  # inherit (inputs.X.Y.dashboards)
  # ;
}
