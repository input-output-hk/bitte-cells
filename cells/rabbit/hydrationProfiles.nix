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
    inherit (terralib) var id;
    c = "create";
    r = "read";
    u = "update";
    d = "delete";
    l = "list";
    s = "sudo";
    acc = nixpkgs.lib.foldl nixpkgs.lib.recursiveUpdate {};
    perNamespaceList = f: builtins.map (n: f n) namespaces;
    perNamespace = f: acc (perNamespaceList f);
  in {
    # ------------------------
    # NOTE: securityGroupRules is a genuine aws config for routing and requires reapply of `tf.core`
    # NOTE: modules are nixosProfiles and require a redeploy of routing
    # ------------------------
    cluster.coreNodes.routing = nixpkgs.lib.mkIf (config.cluster.infraType == "aws") {
      modules = [nixosProfiles.routing];
      securityGroupRules = {
        amqps = {
          port = 5671;
          protocols = ["tcp"];
          cidrs = ["0.0.0.0/0"];
        };
      };
    };
    cluster.premNodes.routing = nixpkgs.lib.mkIf (config.cluster.infraType == "prem") {
      modules = [nixosProfiles.routing];
    };
    # ------------------------
    # hydrate-cluster
    # ------------------------
    tf.hydrate-cluster.configuration = {
      locals.policies = {
        vault."nomad-cluster" = {
          path."consul/creds/rabbit".capabilities = [r];
          path."pki/issue/rabbit".capabilities = [c u];
          path."pki/roles/rabbit".capabilities = [r];
        };
        consul.rabbit = {
          key_prefix = perNamespace (
            namespace: {
              "rabbitmq/${namespace}-rabbit" = {
                policy = "write";
                intentions = "deny";
              };
            }
          );
          service_prefix = perNamespace (
            namespace: {
              "${namespace}-rabbit" = {
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
      resource.vault_pki_secret_backend_role.rabbit = {
        # backend = var "vault_pki_secret_backend.pki.path";
        backend = "pki";
        name = "rabbit";
        key_type = "ec";
        key_bits = 256;
        allow_any_name = true;
        enforce_hostnames = false;
        generate_lease = true;
        key_usage = ["DigitalSignature" "KeyAgreement" "KeyEncipherment"];
        # 87600h
        max_ttl = "315360000";
      };
    };
  };
}
