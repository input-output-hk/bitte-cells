{
  inputs,
  cell,
}: let
  inherit (inputs.nixpkgs) system;
  entrypoints' = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#${system}.dgraph.entrypoints";
  healthChecks' = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#${system}.dgraph.healthChecks";
  inherit (cell) entrypoints healthChecks;
in {
  default = {
    namespace,
    datacenters ? ["eu-central-1" "eu-west-1" "us-east-2"],
    domain,
    nodeClass,
    scaling,
  }: let
    id = "dgraph";
    type = "service";
    dbName = "dbsync";
    priority = 50;
  in {
    job.dgraph = {
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
          attribute = "\${meta.dgraph}";
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
      group.dgraph = {
        count = scaling;
        service = [
          (import ./srv-node.nix {inherit namespace healthChecks;})
          (import ./srv-wallet.nix {inherit namespace healthChecks;})
          (import ./srv-db-sync.nix {inherit namespace healthChecks;})
          (import ./srv-submit-api.nix {inherit namespace healthChecks;})
        ];
        ephemeral_disk = [
          {
            migrate = true;
            size = 80000;
            sticky = true;
          }
        ];
        network = {
          dns = [{servers = ["172.17.0.1"];}];
          mode = "bridge";
          port = {
            envoyPrometheus = [{to = 9091;}];
            node = [{to = 3001;}];
          };
        };
        volume = {
          persistDbSync = {
            # volume name configured via nixosProfiles.client
            source = "${namespace}-db-sync";
            type = "host";
          };
          persistWallet = {
            # volume name configured via nixosProfiles.client
            source = "${namespace}-wallet";
            type = "host";
          };
        };
        # ----------
        # Task: Zero
        # ----------
        task.zero = {
          config = {
            flake = "${entrypoints'}.dgraph-zero-entrypoint";
            command = "/bin/dgraph-zero-entrypoint";
            args = [];
            flake_deps = ["${healthChecks'}.tbc"];
          };
          driver = "exec";
          kill_signal = "SIGINT";
          resources = {
            cpu = 8000;
            memory = 16384;
          };
        };
        # ----------
        # Task: Alpha
        # ----------
        task.alpha = {
          config = {
            flake = "${entrypoints'}.dgraph-alpha-entrypoint";
            command = "/bin/dgraph-alpha-entrypoint";
            args = [];
            flake_deps = [];
          };
          driver = "exec";
          kill_signal = "SIGINT";
          resources = {
            cpu = 8000;
            memory = 16384;
          };
        };
      };
    };
  };
}
