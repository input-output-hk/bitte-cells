{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
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
    perNamespace = f: acc (builtins.map (n: f n) namespaces);
  in
    {
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
                "service/testnet-${namespace}".policy = "write";
                "service/testnet-${namespace}".intentions = "deny";
              }
            );
            service_prefix = perNamespace (
              namespace: {
                "testnet-${namespace}".policy = "write";
                "testnet-${namespace}".intentions = "deny";
              }
            );
            session_prefix = {
              "".policy = "write";
              "".intentions = "deny";
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
