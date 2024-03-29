{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (cell) nixosProfiles;
in {
  hydrate-cluster = namespaces: {
    terralib,
    config,
    ...
  }: let
    inherit (terralib) allowS3ForTempo;
    bucketTempoArn = "arn:aws:s3:::${config.cluster.s3Tempo}";
    allowS3ForTempoBucket = allowS3ForTempo bucketTempoArn;
    inherit (terralib) var id;
    acc = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate {};
    perNamespaceList = f: builtins.map (n: f n) namespaces;
    perNamespace = f: acc (perNamespaceList f);
  in {
    # ------------------------
    # NOTE: Modules are nixosProfiles and require a redeploy of routing
    # NOTE: We are not modifying aws security groups for world exposure as tempo services
    #       are consumed by cluster internal clients
    # ------------------------
    cluster.coreNodes.routing = nixpkgs.lib.mkIf (config.cluster.infraType == "aws") {
      modules = [nixosProfiles.routing];
    };
    cluster.premNodes.routing = nixpkgs.lib.mkIf (config.cluster.infraType == "prem") {
      modules = [nixosProfiles.routing];
    };

    # ------------------------------------------------------------------------------------------
    # NOTE: these are genuine aws client instance roles and currently require a `tf.clients` apply
    # ------------------------------------------------------------------------------------------

    # For now, a single tempo bucket per cluster is being utilized
    cluster.iam.roles.client.policies = allowS3ForTempoBucket "cluster";

    # FIXME: consolidate policy reconciliation loop with TF
    # PROBLEM: requires bootstrapper reconciliation loop

    # Clients need the capability to impersonate the `tempo` role
    services.vault.policies.client = {
      path."auth/token/create/tempo".capabilities = ["update"];
      path."auth/token/roles/tempo".capabilities = ["read"];
    };

    # ------------------------
    # hydrate-cluster
    # ------------------------
    tf.hydrate-cluster.configuration = {
      locals.policies = {
        vault.tempo.path = perNamespace (
          namespace: {
            "kv/data/tempo/${namespace}".capabilities = ["read" "list"];
            "kv/metadata/tempo/${namespace}".capabilities = ["read" "list"];
          }
        );
      };
    };
  };
}
