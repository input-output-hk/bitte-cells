{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge cells;
  inherit (inputs.nixpkgs) system;
  inherit (inputs.cells._utils) nomadFragments;
  inherit (cell) entrypoints oci-images packages;

  # OCI-Image Namer
  ociNamer = oci: l.unsafeDiscardStringContext "${oci.imageName}:${oci.imageTag}";
  l = inputs.nixpkgs.lib // builtins;
in
  with data-merge; {
    default = {
      namespace,
      datacenters,
      domain,
      extraTempo ? {},
      extraVector ? {},
      nodeClass,
      scaling,
      ...
    }: let
      id = "tempo";
      type = "service";
      priority = 50;
      # subdomain = "patroni.${domain}";
      # consulPath = "consul/creds/patroni";
      # patroniSecrets = {
      #   __toString = _: "kv/patroni/${namespace}";
      #   patroniApi = ".Data.data.patroniApi";
      #   patroniApiPass = ".Data.data.patroniApiPass";
      #   patroniRepl = ".Data.data.patroniRepl";
      #   patroniReplPass = ".Data.data.patroniReplPass";
      #   patroniRewind = ".Data.data.patroniRewind";
      #   patroniRewindPass = ".Data.data.patroniRewindPass";
      #   patroniSuper = ".Data.data.patroniSuper";
      #   patroniSuperPass = ".Data.data.patroniSuperPass";
      # };
      # vaultPkiPath = "pki/issue/patroni";
      # patroniYaml = "secrets/patroni.yaml";
      # volumeMount = "/persist-db";
    in {
      job.tempo = {
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
            operator = "distinct_hosts";
            value = "true";
          }
        ];
        spread = [{attribute = "\${attr.platform.aws.placement.availability-zone}";}];
        # ----------
        # Update
        # ----------
        update.health_check = "task_states";
        update.healthy_deadline = "5m0s";
        update.max_parallel = 1;
        update.min_healthy_time = "2m";
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
        group.tempo =
          merge
          {}
          # (cells.vector.nomadTask.default {
          #   inherit namespace;
          #   # TODO: Once network bridge mode hairpinning is fixed
          #   # switch to using the host IP to improve endpoint metrics
          #   # reporting which now will report only 127.0.0.1 for each
          #   # patroni member, with the distinguishing metric being
          #   # nomad_alloc_name.
          #   #
          #   # Refs:
          #   #   https://github.com/hashicorp/nomad/issues/13352
          #   #   https://github.com/hashicorp/nomad/pull/13834
          #   #
          #   # Switch to:
          #   # endpoints = ["https://$NOMAD_ADDR_patroni/metrics"];
          #   endpoints = ["https://127.0.0.1:8008/metrics"];

          #   extra = {
          #     # Until we implement app based mTLS, or alternatively
          #     # generate vault pki certs for vector consumption
          #     # with rotation and SIGHUP consul template restarts.
          #     sources.prom.tls.verify_certificate = false;

          #     # Avoid repeating duplicate fingerprint logs for
          #     # stdout between patroni and backup-walg logs.
          #     sources.source_stdout.fingerprint.strategy = "checksum";
          #     sources.source_stdout.fingerprint.lines = 4;
          #     sources.source_stdout.fingerprint.ignored_header_bytes = 0;
          #   } // extraVector;
          # })
          {
            count = scaling;
            ephemeral_disk = {
              migrate = true;
              size = 5000;
              sticky = true;
            };
            network = {
              dns = {servers = ["172.17.0.1"];};
              mode = "bridge";
              port = {
                tempo = {
                  to = 3200;
                };
                tempo-otlp-grpc = {
                  to = 4317;
                };
                tempo-jaeger-thrift-http = {
                  to = 14268;
                };
              };
            };
            service = import ./srv-rest.nix {inherit namespace;};
            task = {
              # ----------
              # Tempo
              # ----------
              tempo =
                import ./env-tempo.nix { inherit inputs namespace packages extraTempo; }
                // {
                  resources = {
                    cpu = 2000;
                    memory = 4096;
                  };
                  driver = "docker";
                  config.image = ociNamer oci-images.tempo;
                  kill_signal = "SIGINT";
                  kill_timeout = "30s";
                  logs = {
                    max_file_size = 100;
                    max_files = 20;
                  };
                  vault = {
                    change_mode = "noop";
                    env = true;
                    policies = ["tempo"];
                  };
                };
            };
          };
      };
    };
  }
