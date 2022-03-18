{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge cells;
  inherit (inputs.nixpkgs) lib;
  inherit (inputs.nixpkgs) system;
  inherit (cell) entrypoints healthChecks constants oci-images;
  # OCI-Image Namer
  ociNamer = oci: "${oci.imageName}:${oci.imageTag}";
in
  with data-merge; {
    # ----------
    # Task: Wallet Init - use per environmet
    # ----------
    wallet-init-check = {
      address_mode = "host";
      args = [];
      command = "${healthChecks.wallet-id-sync}/bin/cardano-wallet-id-sync-check";
      interval = "30s";
      # on_update = "ignore_warnings";
      # check_restart.ignore_warnings = true;
      timeout = "10s";
      type = "script";
    };
    wallet-init-task = {namespace, ...}: let
      walletSecrets = {
        __toString = _: "kv/nomad-cluster/${namespace}/wallet";
        cardanoWalletInitData = ".Data.data.cardanoWalletInitData";
        cardanoWalletInitName = ".Data.data.cardanoWalletInitName";
        cardanoWalletInitPass = ".Data.data.cardanoWalletInitPass";
      };
    in {
      config.image = ociNamer oci-images.wallet-init;
      driver = "docker";
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
      restart = {
        attempts = 10;
        delay = "1m0s";
        interval = "30m0s";
        mode = "fail";
      };
      env = {
        WALLET_SRV_URL = "TO-BE-OVERRIDDEN";
        CARDANO_WALLET_ID = "TO-BE-OVERRIDDEN";
      };
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

    default = {
      namespace,
      datacenters ? ["eu-central-1" "eu-west-1" "us-east-2"],
      domain,
      nodeClass,
      scaling,
      # extra config switches
      submit ? true,
      wallet ? true,
      dbsync ? true,
      ...
    }: let
      id = "cardano";
      type = "service";
      dbName = "dbsync";
      priority = 50;
      volumeMountWallet = constants.stateDirs.wallet;
      volumeMountDbSync = constants.stateDirs.dbSync;
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
        group.cardano =
          merge
          (cells.vector.nomadTask.default {
            endpoints =
              ["http://127.0.0.1:12798"] # node
              ++ (lib.optionals wallet ["http://127.0.0.1:8081"])
              ++ (lib.optionals dbsync ["http://127.0.0.1:8080"]);
          })
          {
            count = scaling;
            service =
              [
                (import ./srv-node.nix {inherit namespace healthChecks;})
              ]
              ++ (lib.optional wallet (import ./srv-wallet.nix {inherit namespace healthChecks;}))
              ++ (lib.optional dbsync (import ./srv-db-sync.nix {inherit namespace healthChecks;}))
              ++ (lib.optional submit (import ./srv-submit-api.nix {inherit namespace healthChecks;}));
            ephemeral_disk = {
              migrate = true;
              size = 80000;
              sticky = true;
            };
            network = {
              dns = {servers = ["172.17.0.1"];};
              mode = "bridge";
              port =
                {
                  envoyPrometheus = {to = 9091;};
                  node = {to = 3001;};
                  # nodeProm = {to = 12798;};
                  # dbSyncProm = {to = 8080;};
                  # walletProm = {to = 8081;};
                }
                // lib.optionalAttrs submit {
                  submit = {to = 8070;};
                }
                // lib.optionalAttrs wallet {
                  wallet = {to = 8090;};
                };
            };
            volume =
              lib.optionalAttrs dbsync {
                persistDbSync = {
                  # volume name configured via nixosProfiles.client
                  source = "${namespace}-db-sync";
                  type = "host";
                };
              }
              // lib.optionalAttrs wallet {
                persistWallet = {
                  # volume name configured via nixosProfiles.client
                  source = "${namespace}-wallet";
                  type = "host";
                };
              };
            task =
              {
                # ----------
                # Task: Node
                # ----------
                node = {
                  config.image = ociNamer oci-images.node-testnet;
                  driver = "docker";
                  resources = {
                    cpu = 5000;
                    memory = 8192;
                  };
                };
              }
              // (
                # ----------
                # Task: Submit-API
                # ----------
                lib.optionalAttrs submit {
                  submit-api = {
                    config.image = ociNamer oci-images.submit-api-testnet;
                    driver = "docker";
                    resources = {
                      cpu = 2000;
                      memory = 4096;
                    };
                  };
                }
              )
              // (
                # ----------
                # Task: Wallet
                # ----------
                lib.optionalAttrs wallet {
                  wallet = {
                    config.image = ociNamer oci-images.wallet-testnet;
                    driver = "docker";
                    vault = {
                      change_mode = "noop";
                      env = true;
                      policies = ["nomad-cluster"];
                    };
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
                }
              )
              // (
                # ----------
                # Task: DbSync
                # ----------
                lib.optionalAttrs dbsync {
                  db-sync = {
                    config.image = ociNamer oci-images.db-sync-testnet;
                    driver = "docker";
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
                          {{ with secret "${dbSyncSecrets}" }}master.${namespace}-database.service.consul:5432:${dbName}:{{ ${
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
                }
              );
          };
      };
    };
  }
