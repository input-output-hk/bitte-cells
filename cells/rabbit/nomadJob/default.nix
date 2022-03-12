{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge;
  inherit (inputs.nixpkgs) system;
  entrypoints' = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#${system}.rabbit.entrypoints";
in {
  default = {
    namespace,
    datacenters ? ["eu-central-1" "eu-west-1" "us-east-2"],
    domain,
    nodeClass,
    scaling,
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
    pkiPath = "pki/issue/rabbit";
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
      group.rabbit = {
        count = scaling;
        network = {
          mode = "host";
          reserved_ports = {
            amqps = [{static = 5671;}];
            clustering = [{static = 25672;}];
            prometheus = [{static = 15692;}];
            epmd = [{static = 4369;}];
            mgmt = [{static = 15672;}];
            rabbitCli1 = [{static = 35672;}];
            rabbitCli10 = [{static = 35681;}];
            rabbitCli2 = [{static = 35673;}];
            rabbitCli3 = [{static = 35674;}];
            rabbitCli4 = [{static = 35675;}];
            rabbitCli5 = [{static = 35676;}];
            rabbitCli6 = [{static = 35677;}];
            rabbitCli7 = [{static = 35678;}];
            rabbitCli8 = [{static = 35679;}];
            rabbitCli9 = [{static = 35680;}];
          };
        };
        service = [(import ./srv-ui.nix {inherit namespace subdomain;})];
        task.rabbitMq = with data-merge;
          (merge
            (import ./env-rabbit-mq.nix {inherit rabbitSecrets consulPath rabbitmqConf namespace;})
            (decorate (import ./env-pki-rabbit-mq.nix {inherit pkiPath subdomain;}) {
              template = append;
            }))
          // {
            config = {
              args = [];
              command = "/bin/rabbit-entrypoint";
              flake = "${entrypoints'}.entrypoint";
              flake_deps = [];
            };
            driver = "exec";
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
