{
  inputs,
  cell,
}: {
  bitte-deadmanssnitch = {
    datasource = "vm";
    rules = [
      {
        alert = "DeadMansSnitch";
        expr = "vector(1)";
        labels.severity = "critical";
        annotations = {
          summary = "[Bitte] DeadMansSnitch Pipeline";
          description = ''
            This is a DeadMansSnitch meant to ensure that the entire alerting pipeline is functional, see: [https://deadmanssnitch.com](https://deadmanssnitch.com).
             This alert should ALWAYS be in alerting state. This enables Deadman's Snitch to report when this monitoring server dies or can otherwise no longer alert.
             In PagerDuty, an event suppression rule can be created for this alert under service integration event rules, with a suppression action and condition of:
             summary  contains  [Bitte] DeadMansSnitch'';
        };
      }
    ];
  };

  inherit
    (import ./alerts/bitte-alerts.nix {})
    bitte-consul
    bitte-loki
    bitte-system
    bitte-vault
    bitte-vm-health
    bitte-vm-standalone
    bitte-vmagent
    ;
}
