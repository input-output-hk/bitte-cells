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

  job = {start}: let
    cfg = start.value."bitte-cells/ci".start;

    templates =
      lib.mapAttrsToList (name: value: {
        destination = name;
        data = value;
      }) {
        "secrets/skopeo" = ''"{{with secret "kv/data/cicero/docker"}}{{with .Data.data}}{{.user}}:{{.password}}{{end}}{{end}}"'';
        "secrets/netrc" = ''
          machine github.com
          login git
          password {{with secret "kv/data/cicero/github"}}{{.Data.data.token}}{{end}}
        '';
        "secrets/auth.json" = ''
          {
            "auths": {
              "docker.infra.aws.iohkdev.io": {
                "auth": "{{with secret "kv/data/cicero/docker"}}{{with .Data.data}}{{base64Encode (print .user ":" .password)}}{{end}}{{end}}"
              }
            }
          }
        '';
      };
  in
    std.chain args [
      actionLib.simpleJob

      (lib.optionalAttrs (start ? statuses_url)
        (std.github.reportStatus start.statuses_url))

      (std.git.clone cfg)

      std.nix.install

      {
        resources = {
          cpu = 15000;
          memory = 9000;
        };

        env.REGISTRY_AUTH_FILE = "/secrets/auth.json";
        template = std.data-merge.append templates;
        config.packages = std.data-merge.append [
          "github:nixos/nixpkgs/nixpkgs-unstable#skopeo"
        ];
      }

      (std.script "bash" ''
        set -exuo pipefail

        fromNix2Container=(
          cardano.oci-images.wallet-init
          ${lib.concatStringsSep "\n" (map (env: ''
            cardano.oci-images.db-sync-${env}
            cardano.oci-images.node-${env}
            cardano.oci-images.submit-api-${env}
            cardano.oci-images.wallet-${env}
          '') [ "testnet" "marlowe-pioneers" ])}
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
