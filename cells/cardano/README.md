# Cardano Cell

# Hydration Profile

- `hydrate-cluster`-mediated hydrtaon requires reapply of cluster hydration

# NixOS Profile

- The `.client` profile inables the patroni selector on a particular client,
  require redeploy of NixOS of that client it also enables the glusterfs
  volumes which requires a _restart_ of nomad on that particular client since
  the folder creation is implemented as a nomad pre-start script.

# Component Switches

- This cell's `nomadJob.default` has the following extra config switches. You
  can disable the respective components:

```nix
{
  sumbit ? true,
  wallet ? true,
  dbsync ? true,
}
```

# NomadJob

- This cell provides a special job target: `wallet-init-task`
- Use this target to initialize a wallet by data-merging it into
  your desired target job
- This cell also provides `wallet-init-check` to also inject a
  healthcheck into a target job of your choice.

_Example usage:_

```nix
backend = data-merge.merge testnet-staging.backend {
  job.backend.group.backend.task.wallet-init = data-merge.merge cardano.nomadJob.wallet-init-task {
    env = { inherit WALLET_SRV_URL CARDANO_WALLET_ID; };
  };
  job.backend.group.backend.task.erc20converter-backend = {
    service = data-merge.update [ 0 ] [
      {
        check = data-merge.append [ (cardano.nomadJob.wallet-init-check envs.staging) ];
      }
    ];
  };
};
```
