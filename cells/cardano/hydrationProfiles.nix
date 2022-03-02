{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  hydrate-cluster = namespaces: {
    terralib,
    config,
    ...
  }: let
    inherit (terralib) var id;
    acc = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate {};
    perNamespaceList = f: builtins.map (n: f n) namespaces;
    perNamespace = f: acc (perNamespaceList f);
  in {
    # ------------------------
    # hydrate-cluster
    # ------------------------
    # ------------------------------------------------------------------------------------------
    # CAVE: Consul requires the tcp declarations to be created first.
    # Otherwise a race condition may occur where some resources can't be made.
    # See the configEntries attribute below:
    #
    #   globalDefaults                    <-- Plan/apply this on the first pass
    #   tcpServices                       <-- Plan/apply this on the first pass
    #   serviceResolverRedirectConfigs    <-- Plan/apply this on a subsequent pass
    #   serviceResolverSubsetsPassing     <-- Plan/apply this on a subsequent pass
    # ------------------------------------------------------------------------------------------
    tf.hydrate-cluster.configuration = let
      # Naming convention helpers
      to_ = name: nixpkgs.lib.replaceStrings ["-"] ["_"] name;
      # Prepared Queries
      preparedQueries = perNamespace (
        namespace: {
          "${to_ namespace}_dbsync_synced" = {
            name = "${namespace}-dbsync-synced";
            service = "${namespace}-dbsync";
            only_passing = true;
          };
          "${to_ namespace}_wallet_synced" = {
            name = "${namespace}-wallet-synced";
            service = "${namespace}-wallet";
            only_passing = true;
          };
        }
      );
      # Consul global defaults
      globalDefaults = {
        proxy_defaults = {
          kind = "proxy-defaults";
          name = "global";
          config_json = builtins.toJSON {config = {protocol = "http";};};
        };
      };
      tcpServices = perNamespace (
        namespace: let
          kind = "service-defaults";
          config_json = builtins.toJSON {protocol = "tcp";};
        in {
          # Atala dbsync stack
          "service_defaults_${to_ namespace}_dbsync" = {
            inherit kind config_json;
            name = "${namespace}-dbsync";
          };
          "service_defaults_${to_ namespace}_dbsync_synced" = {
            inherit kind config_json;
            name = "${namespace}-dbsync-synced";
          };
        }
      );
      # Service resolver
      serviceResolver = perNamespace (
        namespace: let
          kind = "service-resolver";
        in {
          "service_resolver_redirect_${to_ namespace}_wallet_synced" = {
            inherit kind;
            name = "${namespace}-wallet-synced";
            config_json = builtins.toJSON {
              redirect = {
                service = "${namespace}-wallet";
                serviceSubset = "${namespace}-wallet-synced";
              };
            };
          };
          "service_resolver_subset_passing_${to_ namespace}_wallet" = {
            inherit kind;
            name = "${namespace}-wallet";
            config_json = builtins.toJSON {
              subsets = {
                "${namespace}-wallet-synced" = {onlyPassing = true;};
              };
              loadbalancer = {
                policy = "maglev";
                hashPolicies = [
                  {
                    field = "header";
                    fieldValue = "x-service-route-id";
                  }
                ];
              };
            };
          };
        }
      );
      # Accumulated consul configuration entries
      configEntries = nixpkgs.lib.foldl' (acc: data: acc // data) {} [globalDefaults tcpServices serviceResolver];
    in {
      resource = {
        consul_prepared_query = preparedQueries;
        consul_config_entry = configEntries;
      };
    };
  };
}
