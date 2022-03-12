# Patroni Cell

## Hydration Profile

- `routing`-mediated hydration requires redeploy of `routing`'s NixOS
- `iam.roles.client`-mediated aws policy hydration for uploading backup to an S3 bucket
  requires reapply of `tf.clients` (it's AWS)
- `hydrate-cluster`-mediated hydration requires reapply of cluster hydration

## NixOS Profile

- The `.routing` profile is used in the above `routing`-mediated hydration
- The `.client` profile enables the patroni selector on a particular client,
  requires redeploy of NixOS of that client
- It also enables the host volumes which requires a _restart_ of nomad on that
  particular client since the folder creation is implemented as a
  nomad pre-start script.
