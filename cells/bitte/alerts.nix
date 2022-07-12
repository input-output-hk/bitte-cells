{
  inputs,
  cell,
}:
{
  bitte-deadmanssnitch = {
    datasource = "vm";
    rules = [
      {
        alert = "DeadMansSnitch";
        expr = "vector(1)";
        labels = { severity = "critical"; };
        annotations = {
          summary = "Alerting DeadMansSnitch.";
          description =
            "This is a DeadMansSnitch meant to ensure that the entire alerting pipeline is functional.";
        };
      }
    ];
  };

  inherit (import ./alerts/bitte-alerts.nix {})
    bitte-loki
    bitte-vm-health
    bitte-vm-standalone
    bitte-vmagent
    ;
}

