{
  inputs,
  cell,
}: {
  default = {patroniNamespace, dbName}: let
    dbSecrets = {
      __toString = _: "kv/nomad-cluster/${patroniNamespace}/database";
      pgUser = ".Data.data.patroniSuper";
      pgPass = ".Data.data.patroniSuperPass";
    };
  in {
    task.pghero = {
      driver = "docker";
      lifecycle.sidecar = false;
      config.image = "ankane/pghero";

      template = [
        {
          change_mode = "restart";
          data = ''
            DATABASE_URL="postgres://{{ with secret "${dbSecrets}" }}{{ ${
              dbSecrets.pgUser
            } }}:{{ ${
              dbSecrets.pgPass
            } }}@master.${patroniNamespace}-database.service.consul:5432/${dbName}{{ end }}"
          '';
          destination = "secrets/env.txt";
          env = true;
          left_delimiter = "{{";
          perms = "0644";
          right_delimiter = "}}";
          splay = "5s";
        }
      ];
    };
  };
}
