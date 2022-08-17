{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge cells;
  inherit (inputs.nixpkgs) system;
  inherit (inputs.cells._utils) nomadFragments;
  inherit (cell) oci-images;
  # OCI-Image Namer
  ociNamer = oci: "${oci.imageName}:${oci.imageTag}";
in
  with data-merge; {
    default = {
      namespace,
      datacenters ? ["eu-central-1" "eu-west-1" "us-east-2"],
      domain,
      extraVector ? {},
      nodeClass,
      scaling,
      ...
    }: let
      id = "rabbit";
      type = "service";
      priority = 50;
      subdomain = "rabbit.${domain}";
      consulPath = "consul/creds/rabbit";
      secretsPath = "kv/nomad-cluster/${namespace}/rabbit";
      rabbitSecrets = {
        __toString = _: "kv/nomad-cluster/${namespace}/rabbit";
        rabbitErlangCookie = ".Data.data.rabbitErlangCookie";
        rabbitAdminPass = ".Data.data.rabbitAdminPass";
        rabbitAdmin = ".Data.data.rabbitAdmin";
      };
      vaultPkiPath = "pki/issue/rabbit";
      rabbitmqConf = "secrets/rabbitmq.conf";
      volumeMount = "/persist-db";
    in {
      job.rabbit = {
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
            attribute = "\${meta.rabbit}";
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
        update.health_check = "checks";
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
        group.rabbit =
          merge
          (cells.vector.nomadTask.default {
            inherit namespace;
            endpoints = ["http://127.0.0.1:15692/metrics"];
            extra = extraVector;
          })
          {
            count = scaling;
            network = {
              dns = {servers = ["172.17.0.1"];};
              mode = "bridge";
              port = {
                amqps = [{to = 5671;}];
                clustering = [{to = 25672;}];
                prometheus = [{to = 15692;}];
                epmd = [{to = 4369;}];
                mgmt = [{to = 15672;}];
                rabbitCli1 = [{to = 35672;}];
                rabbitCli10 = [{to = 35681;}];
                rabbitCli2 = [{to = 35673;}];
                rabbitCli3 = [{to = 35674;}];
                rabbitCli4 = [{to = 35675;}];
                rabbitCli5 = [{to = 35676;}];
                rabbitCli6 = [{to = 35677;}];
                rabbitCli7 = [{to = 35678;}];
                rabbitCli8 = [{to = 35679;}];
                rabbitCli9 = [{to = 35680;}];
              };
            };
            service = [(import ./srv-ui.nix {inherit namespace subdomain;})];
            task.rabbitMq =
              (
                merge
                (import ./env-rabbit-mq.nix {inherit rabbitSecrets consulPath rabbitmqConf namespace;})
                {template = nomadFragments.workload-identity-vault {inherit vaultPkiPath;};}
              )
              // {
                config.image = ociNamer oci-images.rabbit;
                driver = "docker";
                kill_signal = "SIGINT";
                kill_timeout = "30s";
                resources = {
                  cpu = 1000;
                  memory = 1024;
                };
                vault = {
                  change_mode = "noop";
                  env = true;
                  policies = ["nomad-cluster"];
                };
              };
          };
      };
    };
  }
