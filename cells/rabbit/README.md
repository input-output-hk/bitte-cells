# Rabbit Cell

# Hydration Profile

- `routing`-mediated hydration requires redeploy of `routing`'s NixOS
- `hydrate-cluster`-mediated hydrtaon requires reapply of cluster hydration

# NixOS Profile

- The `.routing` profile is used in the above `routing`-mediated hydration
- The `.client` profile inables the rabbit selector on a particular client,
  require redeploy of NixOS of that client
