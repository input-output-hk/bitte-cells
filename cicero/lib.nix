{
  cicero,
  lib,
}: let
  inherit (cicero.lib) std;
  actionLib = import "${cicero}/action-lib.nix" {inherit std lib;};
in
  actionLib
  // {
    common = {
      inputStartCue = ''
        clone_url:       string
        sha:             string
        statuses_url?:   string
        ref?:            "refs/heads/\(default_branch)"
        default_branch?: string
      '';

      output = action: start: {
        success."${action.name}" =
          {
            ok = true;
            inherit (start) clone_url sha;
          }
          // lib.optionAttrs (start ? statuses_url) {
            inherit (start) statuses_url;
          }
          // lib.optionAttrs (start ? ref) {
            inherit (start) ref default_branch;
          };
      };

      task = start: action: next:
        std.chain action [
          (lib.optionalAttrs (start ? statuses_url)
            (std.github.reportStatus start.statuses_url))

          {
            template = std.data-merge.append [
              {
                destination = "secrets/netrc";
                data = ''
                  machine github.com
                  login git
                  password {{with secret "kv/data/cicero/github"}}{{.Data.data.token}}{{end}}
                '';
              }
              {
                destination = "secrets/skopeo";
                data = ''"{{with secret "kv/data/cicero/docker"}}{{with .Data.data}}{{.user}}:{{.password}}{{end}}{{end}}"'';
              }
              {
                destination = "secrets/auth.json";
                data = ''
                  {
                    "auths": {
                      "docker.infra.aws.iohkdev.io": {
                        "auth": "{{with secret "kv/data/cicero/docker"}}{{with .Data.data}}{{base64Encode (print .user ":" .password)}}{{end}}{{end}}"
                      }
                    }
                  }
                '';
              }
            ];

            resources = {
              cpu = 15000;
              memory = 6144;
            };

            env.REGISTRY_AUTH_FILE = "/secrets/auth.json";
          }

          (std.git.clone start)

          std.nix.install

          next
        ];
    };
  }
