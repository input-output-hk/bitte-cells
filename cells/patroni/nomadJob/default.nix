{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge cells;
  inherit (inputs.nixpkgs) system;
  inherit (inputs.cells._utils) nomadFragments;
  entrypoints' = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#${system}.patroni.entrypoints";
  inherit (cell) entrypoints;
in
  with data-merge; {
    default = {
      namespace,
      datacenters ? ["eu-central-1" "eu-west-1" "us-east-2"],
      domain,
      nodeClass,
      scaling,
      ...
    }: let
      id = "database";
      type = "service";
      priority = 50;
      subdomain = "patroni.${domain}";
      consulPath = "consul/creds/patroni";
      patroniSecrets = {
        __toString = _: "kv/nomad-cluster/${namespace}/database";
        patroniApi = ".Data.data.patroniApi";
        patroniApiPass = ".Data.data.patroniApiPass";
        patroniRepl = ".Data.data.patroniRepl";
        patroniReplPass = ".Data.data.patroniReplPass";
        patroniRewind = ".Data.data.patroniRewind";
        patroniRewindPass = ".Data.data.patroniRewindPass";
        patroniSuper = ".Data.data.patroniSuper";
        patroniSuperPass = ".Data.data.patroniSuperPass";
      };
      vaultPkiPath = "pki/issue/postgres";
      patroniYaml = "secrets/patroni.yaml";
      volumeMount = "/persist-db";
    in {
      job.database = {
        inherit namespace datacenters id type priority;
        # ----------
        # Scheduling
        # ----------
        constraint = [
          {
            attribute = "\${node.class}";
            operator = "=";
            value = "${nodeClass}";
          }
          {
            attribute = "\${meta.patroni}";
            operator = "is_set";
          }
          {
            operator = "distinct_hosts";
            value = "true";
          }
        ];
        spread = [{attribute = "\${node.datacenter}";}];
        # ----------
        # Update
        # ----------
        update.health_check = "task_states";
        update.healthy_deadline = "5m0s";
        update.max_parallel = 1;
        update.min_healthy_time = "10s";
        update.progress_deadline = "10m0s";
        update.stagger = "30s";
        # ----------
        # Migrate
        # ----------
        migrate.health_check = "checks";
        migrate.healthy_deadline = "8m20s";
        migrate.max_parallel = 1;
        migrate.min_healthy_time = "10s";
        # ----------
        # Reschedule
        # ----------
        reschedule.delay = "30s";
        reschedule.delay_function = "exponential";
        reschedule.max_delay = "1h0m0s";
        reschedule.unlimited = true;
        # ----------
        # Task Groups
        # ----------
        group.database =
          merge
          (cells.vector.nomadTask.default {
            inherit namespace;
            # Patroni requires the rest interface to be publicly
            # bound, accessible over the network by other cluster
            # members and the metrics endpoint is served from the
            # same binding.  Therefore, we need to scrape the host
            # IP:PORT for metrics.
            endpoints = ["https://$NOMAD_ADDR_patroni/metrics"];

            extra = {
              # Until we implement app based mTLS, or alternatively
              # generate vault pki certs for vector consumption
              # with rotation and SIGHUP consul template restarts.
              #
              # Undocumented option:
              # https://github.com/vectordotdev/vector/issues/12129
              sources.prom.tls.verify_certificate = false;

              # Avoid repeating duplicate fingerprint logs for
              # stdout between patroni and backup-walg logs.
              sources.source_stdout.fingerprint.strategy = "checksum";
              sources.source_stdout.fingerprint.lines = 2;
              sources.source_stdout.fingerprint.ignored_header_bytes = 0;
            };
          })
          {
            count = scaling;
            ephemeral_disk = {
              migrate = true;
              size = 5000;
              sticky = true;
            };
            network = {
              mode = "host";
              reserved_ports = {
                psql = {static = 5432;};
                patroni = {static = 8008;};
              };
            };
            service = [(import ./srv-rest.nix {inherit namespace subdomain;})];
            volume = {
              persistDb = {
                source = "${namespace}-database";
                type = "host";
              };
            };
            task = {
              # ----------
              # Backup wal-g
              # ----------
              backup-walg =
                (
                  import ./env-backup-walg.nix {inherit patroniSecrets volumeMount;}
                )
                // {
                  resources = {
                    cpu = 500;
                    memory = 1024;
                  };
                  driver = "exec";
                  config = {
                    args = [];
                    command = "/bin/patroni-backup-sidecar-entrypoint";
                    flake = "${entrypoints'}.backup-sidecar-entrypoint";
                    flake_deps = [];
                  };
                  kill_signal = "SIGINT";
                  kill_timeout = "30s";
                  lifecycle = {
                    hook = "poststart";
                    sidecar = true;
                  };
                  vault = {
                    change_mode = "noop";
                    env = true;
                    policies = ["nomad-cluster"];
                  };
                  volume_mount = {
                    destination = volumeMount;
                    propagation_mode = "private";
                    volume = "persistDb";
                  };
                };
              # ----------
              # Patroni
              # ----------
              patroni = with data-merge;
                (
                  merge
                  (import ./env-patroni.nix {inherit patroniSecrets consulPath volumeMount patroniYaml namespace;})
                  {template = nomadFragments.workload-identity-vault {inherit vaultPkiPath;};}
                )
                // {
                  resources = {
                    cpu = 2000;
                    memory = 4096;
                  };
                  driver = "exec";
                  config = {
                    command = "/bin/patroni-entrypoint";
                    args = [patroniYaml];
                    flake = "${entrypoints'}.entrypoint";
                    flake_deps = [];
                  };
                  kill_signal = "SIGINT";
                  kill_timeout = "30s";
                  logs = {
                    max_file_size = 100;
                    max_files = 20;
                  };
                  vault = {
                    change_mode = "noop";
                    env = true;
                    policies = ["nomad-cluster"];
                  };
                  volume_mount = {
                    destination = volumeMount;
                    propagation_mode = "private";
                    volume = "persistDb";
                  };
                };
            };
          };
      };
    };
  }
