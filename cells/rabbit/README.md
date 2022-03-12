# Rabbit Cell

## Hydration Profile

- `routing`-mediated hydration requires redeploy of `routing`'s NixOS & `tf.core` (sec rules)
- `hydrate-cluster`-mediated hydration requires reapply of cluster hydration

## NixOS Profile

- The `.routing` profile is used in the above `routing`-mediated hydration
- The `.client` profile enables the rabbit selector on a particular client,
  requires redeploy of NixOS of that client.
