{ namespace
, healthChecks
}:
{
  address_mode = "auto";
  check = [
    {
      address_mode = "host";
      interval = "1m0s";
      port = "node";
      timeout = "2s";
      type = "tcp";
    }
    {
      address_mode = "host";
      args = [ ];
      command = "${
        builtins.unsafeDiscardStringContext (toString healthChecks.node-network-testnet-sync)
      }/bin/cardano-node-network-testnet-sync-check";
      interval = "30s";
      # on_update = "ignore_warnings";
      # check_restart.ignore_warnings = true;
      task = "node";
      timeout = "10s";
      type = "script";
    }
  ];
  name = "${namespace}-node";
  port = "node";
}
