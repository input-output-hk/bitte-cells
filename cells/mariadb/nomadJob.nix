{
  cell,
  inputs,
}: {
  default = {
    namespace,
    datacenters,
    ...
  }: {
    job.mariadb = {
      inherit datacenters namespace;

      group.mysql = {
        restart = {
          attempts = 5;
          delay = "10s";
          interval = "1m";
          mode = "delay";
        };

        reschedule = {
          delay = "10s";
          delay_function = "exponential";
          max_delay = "1m";
          unlimited = true;
        };

        network.port.mysql.to = "3306";

        service = [
          {
            name = "mysql";
            address_mode = "auto";
            port = "mysql";
            check = [
              {
                type = "tcp";
                port = "mysql";
                interval = "10s";
                timeout = "2s";
              }
            ];
          }
        ];

        task.mysql = {
          driver = "docker";

          config = {
            image = "mariadb:10";
            ports = ["mysql"];
            # command = "mysqld";
          };

          resources = {
            memory = 1024;
            cpu = 300;
          };

          vault.policies = ["nomad-cluster"];

          template = [
            {
              env = true;
              destination = "secrets/mysql";
              data = ''
                MARIADB_ROOT_PASSWORD={{with secret "kv/data/nomad-cluster/mysql-root"}}{{.Data.data.password}}{{end}}
              '';
            }
          ];
        };
      };
    };
  };
}
