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
    inherit (terralib) allowS3For;
    bucketArn = "arn:aws:s3:::${config.cluster.s3Bucket}";
    allowS3ForBucket = allowS3For bucketArn;
    inherit (terralib) var id;
    acc = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate {};
    perNamespaceList = f: builtins.map (n: f n) namespaces;
    perNamespace = f: acc (perNamespaceList f);
  in {
    # ------------------------------------------------------------------------------------------
    # NOTE: these are genuine aws client instance roles and currently require a `tf.clients` apply
    # ------------------------------------------------------------------------------------------
    cluster.iam.roles.client.policies = perNamespace (
      namespace: allowS3ForBucket "postgres-backups-${namespace}" "backups/${namespace}" ["walg"]
    );
    # FIXME: consolidate policy reconciliation loop with TF
    # PROBLEM: requires bootstrapper reconciliation loop
    # clients need the capability to impersonate the `patroni` role
    services.vault.policies.client = {
      path."consul/creds/patroni".capabilities = ["read"];
      path."auth/token/create/patroni".capabilities = ["update"];
      path."auth/token/roles/patroni".capabilities = ["read"];
    };
    # ------------------------
    # hydrate-cluster
    # ------------------------
    tf.hydrate-cluster.configuration = {
      locals.policies = {
        vault.patroni.path = perNamespace (
          namespace: {
            "consul/creds/patroni".capabilities = ["read"];
            "kv/data/patroni/${namespace}".capabilities = ["read" "list"];
            "kv/metadata/patroni/${namespace}".capabilities = ["read" "list"];
          }
        );
        consul.patroni = {
          key_prefix = perNamespace (
            namespace: {
              "service/${namespace}-database" = {
                policy = "write";
                intentions = "deny";
              };
            }
          );
          service_prefix = perNamespace (
            namespace: {
              "${namespace}-database" = {
                policy = "write";
                intentions = "deny";
              };
            }
          );
          session_prefix = {
            "" = {
              policy = "write";
              intentions = "deny";
            };
          };
        };
      };
    };
  };
}
