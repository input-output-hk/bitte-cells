{ inputs
, cell
}:
let
  inherit (inputs) nixpkgs;
  inherit (cell) nixosProfiles;
in
{
  hydrate-cluster = namespaces: { terralib
  , config
  , ...
  }:
  let
    inherit (terralib) allowS3For;
    bucketArn = "arn:aws:s3:::${config.cluster.s3Bucket}";
    allowS3ForBucket = allowS3For bucketArn;
    inherit (terralib) var id;
    c = "create";
    r = "read";
    u = "update";
    d = "delete";
    l = "list";
    s = "sudo";
    acc = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate { };
    perNamespaceList = f: builtins.map (n: f n) namespaces;
    perNamespace = f: acc (perNamespaceList f);
  in
    {
      # ------------------------
      # CAVE: this is a genuine aws config for routing and requires reapply of `tf.core`
      # CAVE: modules are nixosProfiles and require a redeploy of routing
      # ------------------------
      cluster.instances.routing = {
        modules = [ nixosProfiles.routing ];
        securityGroupRules = {
          psql = {
            port = 5432;
            protocols = [ "tcp" ];
            cidrs = [ "0.0.0.0/0" ];
          };
        };
      };
      # ------------------------------------------------------------------------------------------
      # CAVE: these are genuine aws client instance roles and currently require a `tf.clients` apply
      # ------------------------------------------------------------------------------------------
      cluster.iam.roles.client.policies = perNamespace (
        namespace: allowS3ForBucket "postgres-backups-${namespace}" "backups/${namespace}" [ "walg" ]
      );
      # ------------------------
      # hydrate-cluster
      # ------------------------
      tf.hydrate-cluster.configuration = {
        locals.policies = {
          vault."nomad-cluster" = {
            path."consul/creds/patroni".capabilities = [ r ];
            path."pki/issue/postgres".capabilities = [ c u ];
            path."pki/roles/postgres".capabilities = [ r ];
          };
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
        resource.vault_pki_secret_backend_role.postgres = {
          # backend = var "vault_pki_secret_backend.pki.path";
          backend = "pki";
          name = "postgres";
          key_type = "ec";
          key_bits = 256;
          allow_any_name = true;
          enforce_hostnames = false;
          generate_lease = true;
          key_usage = [ "DigitalSignature" "KeyAgreement" "KeyEncipherment" ];
          # 87600h
          max_ttl = "315360000";
        };
      };
    };
}
