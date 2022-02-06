{ namespace }:
let
  walgBackupFromReplica = false;
  walgDaysToRetain = 7;
in
{
  env = {
    PATH = "/bin";
    PGDATA = "/persist-db/postgres/patroni";
    PGHOST = "/alloc";
    SLEEP_COUNTER = "4320";
    SLEEP_PERIOD = "10";
    PG_NODE = "pg-\${NOMAD_ALLOC_INDEX}";
    WALG_BACKUP_FROM_REPLICA = walgBackupFromReplica;
    WALG_DAYS_TO_RETAIN = walgDaysToRetain;
    INIT_CONN_DB = "postgres";
    PGPORT = "\${NOMAD_PORT_psql}";
    DB = "SPECIFIED-IN-FLAKE";
    WALG_S3_PREFIX = "SPECIFIED-IN-FLAKE";
  };
  template = [
    {
      change_mode = "restart";
      data = ''
        {{with secret "kv/nomad-cluster/${namespace}/database"}}
        INIT_USER="{{.Data.data.patroniSuper}}"
        {{end}}
      '';
      destination = "secrets/env.txt";
      env = true;
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
  ];
}
