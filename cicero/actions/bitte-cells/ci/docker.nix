{
  name,
  std,
  lib,
  actionLib,
  ...
} @ args: {
  inputs.start = ''
    "bitte-cells/ci": start: {
      clone_url:       string
      sha:             string
      statuses_url?:   string
      ref?:            "refs/heads/\(default_branch)"
      default_branch?: string
    }
  '';

  output = {start}: {
    success."${name}" =
      {
        ok = true;
      }
      // start.value."bitte-cells/ci";
  };

  job = {start}:
    std.chain args [
      actionLib.simpleJob

      (actionLib.common.task
        start.value."bitte-cells/ci")

      (std.script "bash" ''
        fromNix2Container=(
          cardano.oci-images.db-sync-testnet
          cardano.oci-images.node-testnet
          cardano.oci-images.submit-api-testnet
          cardano.oci-images.wallet-init
          cardano.oci-images.wallet-testnet
          vector.oci-images.default
        )

        fromDockerTools=(
          patroni.oci-images.patroni
          patroni.oci-images.patroni-backup-sidecar
        )

        for attr in "''${fromNix2Container[@]}"; do
          echo "pushing $attr"
          nix run ".#x86_64-linux.$attr.copyToRegistry"
        done

        for attr in "''${fromDockerTools[@]}"; do
          echo "pushing $attr"

          name="$(nix eval ".#x86_64-linux.$attr.imageName")"
          tag="$(nix eval ".#x86_64-linux.$attr.imageTag")"

          nix build ".#x86_64-linux.$attr"
          skopeo copy "docker-archive:$(readlink -f ./result)" \
            "docker://$name:$tag" \
            --insecure-policy \
            --dest-creds "<(secrets/skopeo)"
        done
      '')
    ];
}
