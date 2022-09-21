{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge cells;
  inherit (cell) oci-images;

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

      inherit (evaluated.config.services.tempo)
        computedServiceConfig
        computedTempoConfig
        ;

      evaluated = l.evalModules {
        modules = [
          ../modules/tempo.nix
          extraTempo
        ];
      };

      tempoConfigFile = (inputs.nixpkgs.formats.yaml {}).generate "config.yaml" computedTempoConfig;
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
        update.min_healthy_time = "1m";
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
          (cells.vector.nomadTask.default {
            inherit namespace;
            # TODO: Once network bridge mode hairpinning is fixed
            # switch to using the host IP to improve endpoint metrics
            # reporting which now will report only 127.0.0.1 for each
            # tempo member, with the distinguishing metric being
            # nomad_alloc_name.
            #
            # Refs:
            #   https://github.com/hashicorp/nomad/issues/13352
            #   https://github.com/hashicorp/nomad/pull/13834
            #
            # Switch to:
            # endpoints = ["http://$NOMAD_ADDR_tempo/metrics"];
            endpoints = ["http://127.0.0.1:3200/metrics"];

            extra = extraVector;
          })
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
              port =  l.foldl' (acc: pname: acc // {
                ${pname} = { to = computedServiceConfig.${pname}.port; };
              }) {} (l.attrNames computedServiceConfig);
            };
            service = import ./srv-rest.nix {inherit l namespace computedServiceConfig;};
            task = {
              # ----------
              # Tempo
              # ----------
              tempo =
                import ./env-tempo.nix {inherit tempoConfigFile;}
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
