{ inputs
, system
}:
let
  nixpkgs = inputs.nixpkgs;
in
{
  hydrate-cluster =
    { terralib
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
    in
      {
        # CAVE: these are genuine aws client instance roles and currently require a `tf.clients` apply
        cluster.iam.roles.client.policies = nixpkgs.lib.foldl (elem: acc: nixpkgs.lib.recursiveUpdate acc elem) { } [
          (
            allowS3ForBucket "postgres-backups-testnet-dev" "backups/testnet-dev" [ "walg" ]
          )
          (
            allowS3ForBucket "postgres-backups-testnet-staging" "backups/testnet-staging" [ "walg" ]
          )
          (
            allowS3ForBucket "postgres-backups-testnet-prod" "backups/testnet-prod" [ "walg" ]
          )
        ];
        tf.hydrate-cluster.configuration = {
          locals.policies = {
            vault."nomad-cluster" = {
              path."consul/creds/patroni".capabilities = [ r ];
              path."pki/issue/postgres".capabilities = [ c u ];
              path."pki/roles/postgres".capabilities = [ r ];
            };
            consul.patroni = {
              key_prefix = {
                "service/testnet-prod-database".policy = "write";
                "service/testnet-prod-database".intentions = "deny";
                "service/testnet-staging-database".policy = "write";
                "service/testnet-staging-database".intentions = "deny";
                "service/testnet-dev-database".policy = "write";
                "service/testnet-dev-database".intentions = "deny";
              };
              service_prefix = {
                "testnet-prod-database".policy = "write";
                "testnet-prod-database".intentions = "deny";
                "testnet-staging-database".policy = "write";
                "testnet-staging-database".intentions = "deny";
                "testnet-dev-database".policy = "write";
                "testnet-dev-database".intentions = "deny";
              };
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
