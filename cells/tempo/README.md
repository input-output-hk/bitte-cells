# Tempo Cell

## Hydration Profile

- `routing`-mediated hydration requires redeploy of `routing`'s NixOS
- `iam.roles.client`-mediated aws policy hydration for accessing s3Tempo bucket
  requires reapply of `tf.clients` (applicable to aws clusters, not prem)
- `hydrate-cluster`-mediated hydration requires reapply of cluster hydration

## NixOS Profile

- The `.routing` profile is used in the above `routing`-mediated hydration
