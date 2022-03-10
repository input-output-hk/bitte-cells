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
        }
      );
      # Service resolver
      serviceResolver = perNamespace (
        namespace: let
          kind = "service-resolver";
        in {
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
