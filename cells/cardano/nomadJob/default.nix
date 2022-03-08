{
  inputs,
  cell,
}: let
  inherit (inputs.nixpkgs) system;
  entrypoints' = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#entrypoints.${system}";
  healthChecks' = "github:input-output-hk/bitte-cells?rev=${inputs.self.rev}#healthChecks.${system}";
  inherit (cell) entrypoints healthChecks constants;
in {
  default = {
    namespace,
    datacenters ? ["eu-central-1" "eu-west-1" "us-east-2"],
    domain,
    nodeClass,
    scaling,
  }: let
    id = "cardano";
    type = "service";
    dbName = "dbsync";
    priority = 50;
    volumeMountWallet = constants.stateDirs.wallet;
    volumeMountDbSync = constants.stateDirs.dbSync;
    walletSecrets = {
      __toString = _: "kv/nomad-cluster/${namespace}/wallet";
      cardanoWalletInitData = ".Data.data.cardanoWalletInitData";
      cardanoWalletInitName = ".Data.data.cardanoWalletInitName";
      cardanoWalletInitPass = ".Data.data.cardanoWalletInitPass";
    };
    dbSyncSecrets = {
      __toString = _: "kv/nomad-cluster/${namespace}/db-sync";
      pgUser = ".Data.data.pgUser";
      pgPass = ".Data.data.pgPass";
    };
  in {
    job.cardano = {
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
          attribute = "\${meta.cardano}";
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
      group.cardano = {
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
        # Task: Node
        # ----------
        task.node = {
          config = {
            flake = "${entrypoints'}.cardano-node-testnet-entrypoint";
            command = "${
              builtins.unsafeDiscardStringContext (toString entrypoints.node-testnet-entrypoint)
            }/bin/cardano-node-testnet-entrypoint";
            args = [];
            flake_deps = ["${healthChecks'}.cardano-node-network-testnet-sync"];
          };
          driver = "exec";
          kill_signal = "SIGINT";
          resources = {
            cpu = 5000;
            memory = 8192;
          };
        };
        # ----------
        # Task: Submit-API
        # ----------
        task.node = {
          config = {
            flake = "${entrypoints'}.cardano-submit-api-testnet-entrypoint";
            command = "${
              builtins.unsafeDiscardStringContext (toString entrypoints.submit-api-testnet-entrypoint)
            }/bin/cardano-submit-api-testnet-entrypoint";
            args = [];
            flake_deps = [];
            # flake_deps = ["${healthChecks'}.cardano-submit-api-network-testnet-sync"];
          };
          driver = "exec";
          kill_signal = "SIGINT";
          resources = {
            cpu = 2000;
            memory = 4096;
          };
        };
        # ----------
        # Task: Wallet
        # ----------
        task.wallet = {
          config = {
            flake = "${entrypoints'}.cardano-wallet-testnet-entrypoint";
            command = "${
              builtins.unsafeDiscardStringContext (toString entrypoints.wallet-testnet-entrypoint)
            }/bin/cardano-wallet-testnet-entrypoint";
            args = [];
            flake_deps = [
              "${healthChecks'}.cardano-wallet-network-sync"
              "${healthChecks'}.cardano-wallet-id-sync"
            ];
          };
          driver = "exec";
          vault = {
            change_mode = "noop";
            env = true;
            policies = ["nomad-cluster"];
          };
          kill_signal = "SIGINT";
          kill_timeout = "30s";
          resources = {
            cpu = 2000;
            memory = 4096;
          };
          env = {
            # used by healthChecks
            CARDANO_WALLET_ID = "TO-BE-OVERRIDDEN";
          };
          volume_mount = {
            destination = volumeMountWallet;
            propagation_mode = "private";
            volume = "persistWallet";
          };
        };
        # ----------
        # Task: Wallet Init
        # ----------
        task.wallet-init = {
          config = {
            flake = "${entrypoints'}.cardano-wallet-init-entrypoint";
            command = "${
              builtins.unsafeDiscardStringContext (toString entrypoints.wallet-init-entrypoint)
            }/bin/cardano-wallet-init-entrypoint";
            args = [];
            flake_deps = [];
          };
          driver = "exec";
          vault = {
            change_mode = "noop";
            env = true;
            policies = ["nomad-cluster"];
          };
          kill_signal = "SIGINT";
          kill_timeout = "30s";
          lifecycle = {hook = "poststart";};
          resources = {
            cpu = 500;
            memory = 128;
          };
          restart = [
            {
              attempts = 10;
              delay = "1m0s";
              interval = "30m0s";
              mode = "fail";
            }
          ];
          env = {CARDANO_WALLET_ID = "TO-BE-OVERRIDDEN";};
          template = [
            {
              change_mode = "restart";
              data = ''
                {{with secret "${walletSecrets}"}}
                # TODO: use toUnescapedJSON after https://github.com/hashicorp/nomad/issues/11568
                CARDANO_WALLET_INIT_DATA="{{ ${
                  walletSecrets.cardanoWalletInitData
                } | toJSON }}"
                CARDANO_WALLET_INIT_NAME="{{ ${
                  walletSecrets.cardanoWalletInitName
                } }}"
                CARDANO_WALLET_INIT_PASS="{{ ${
                  walletSecrets.cardanoWalletInitPass
                } }}"
                {{end}}
              '';
              destination = "secrets/env.sh";
              env = true;
              left_delimiter = "{{";
              # FIXME: restrict once https://github.com/hashicorp/nomad/issues/5020#issuecomment-1023140860
              # is implemented in nomad
              # also clean up: entrypoints/db-sync-entrypoint.sh
              perms = "0777";
              right_delimiter = "}}";
              splay = "5s";
            }
          ];
        };
        # ----------
        # Task: DbSync
        # ----------
        task.db-sync = {
          config = {
            flake = "${entrypoints'}.cardano-db-sync-testnet-entrypoint";
            command = "${
              builtins.unsafeDiscardStringContext (toString entrypoints.db-sync-testnet-entrypoint)
            }/bin/cardano-db-sync-testnet-entrypoint";
            args = [];
            flake_deps = ["${healthChecks'}.cardano-db-sync-network-testnet-sync"];
          };
          driver = "exec";
          kill_signal = "SIGINT";
          resources = {
            cpu = 5000;
            memory = 12288;
          };
          volume_mount = {
            destination = volumeMountDbSync;
            propagation_mode = "private";
            volume = "persistDbSync";
          };
          env = {PGPASSFILE = "/secrets/pgpass";};
          template = [
            {
              change_mode = "restart";
              # CAVE: no empty newlines in the rendered template!!
              data = ''
                {{ with secret "${dbSyncSecrets}" }}master.${namespace}-database.service.consul:5432:${
                  dbName
                }:{{ ${
                  dbSyncSecrets.pgUser
                } }}:{{ ${
                  dbSyncSecrets.pgPass
                } }}{{ end }}
              '';
              destination = "secrets/pgpass";
              left_delimiter = "{{";
              perms = "0644";
              right_delimiter = "}}";
              splay = "5s";
            }
          ];
        };
      };
    };
  };
}
