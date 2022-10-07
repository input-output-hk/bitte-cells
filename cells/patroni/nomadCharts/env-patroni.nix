{
  patroniSecrets,
  consulPath,
  patroniYaml,
  volumeMount,
  namespace,
  packages,
  psqlPort,
}: let
  patroniBootstrapMethod = "initdb";
  patroniBootstrapMethodWalgPitrTimeline = "latest";
  patroniBootstrapMethodWalgPitrTimestamp = "'2022-01-01 00:00:00 UTC'";
  patroniBootstrapMethodWalgTimeline = "latest";
in {
  env = {
    PATH = "/bin";
    PERSISTENCE_MOUNTPOINT = volumeMount;
    WALG_S3_PREFIX = "SPECIFIED-IN-FLAKE";
  };
  template = [
    {
      change_mode = "restart";
      data = ''
        {{ with secret "${consulPath}" }}
        CONSUL_HTTP_TOKEN="{{ .Data.token }}"
        PATRONI_CONSUL_TOKEN="{{ .Data.token }}"
        PATRONICTL_CONFIG_FILE="${patroniYaml}"
        {{ end }}

        CONSUL_HTTP_ADDR="172.17.0.1:8500"
        TERM="xterm-256color"
        # Add wal-g debugging if required
        #
        # WALG_LOG_LEVEL="DEVEL"
      '';
      destination = "secrets/env.txt";
      env = true;
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{with secret "${patroniSecrets}"}}
        ---
        scope: ${namespace}-database
        name: pg-{{ env "NOMAD_ALLOC_INDEX" }}

        restapi:
          authentication:
            username: {{ ${patroniSecrets.patroniApi} }}
            password: {{ ${patroniSecrets.patroniApiPass} }}
          cafile: '/run/postgresql/ca.pem'
          certfile: '/run/postgresql/cert.pem'
          keyfile: '/run/postgresql/key.pem'
          connect_address: {{ env "NOMAD_IP_patroni" }}:{{ env "NOMAD_PORT_patroni" }}
          http_extra_headers:
            'X-Frame-Options': 'SAMEORIGIN'
            'X-XSS-Protection': '1; mode=block'
            'X-Content-Type-Options': 'nosniff'
          https_extra_headers:
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains'
          listen: 0.0.0.0:{{ env "NOMAD_PORT_patroni" }}
          verify_client: none

        consul:
          url: http://172.17.0.1:8500
          register_service: true
          service_tags:
          - {{ env "NOMAD_ALLOC_ID" }}

        bootstrap:
          dcs:
            loop_wait: 10
            master_start_timeout: 300
            master_stop_timeout: -1
            maximum_lag_on_failover: 1048576
            maximum_lag_on_syncnode: -1
            max_timelines_history: 0
            retry_timeout: 10
            synchronous_mode: true
            ttl: 30

            postgresql:
              use_pg_rewind: true
              use_slots: true

              pg_hba:
              - local   all         all                                   trust
              - hostssl all         {{${patroniSecrets.patroniSuper}}}    127.0.0.1/32   trust
              - hostssl all         {{${patroniSecrets.patroniSuper}}}    all            scram-sha-256
              - hostssl all         all                                   10.0.0.0/8     scram-sha-256
              - hostssl all         all                                   172.26.66.0/23 scram-sha-256
              - hostssl all         all                                   172.17.0.1/16  scram-sha-256
              - hostssl replication {{${patroniSecrets.patroniRepl}}}     127.0.0.1/32   scram-sha-256
              - hostssl replication {{${patroniSecrets.patroniRepl}}}     10.0.0.0/8     scram-sha-256

              parameters:
                # Patroni required dcs params
                # Ref:
                #  https://patroni.readthedocs.io/en/latest/dynamic_configuration.html
                #
                hot_standby: on
                max_connections: 1024
                max_locks_per_transaction: 64
                max_prepared_transactions: 0
                max_replication_slots: 10
                max_wal_senders: 10
                max_worker_processes: 8
                wal_level: logical
                wal_log_hints: on
                track_commit_timestamp: off

                # Additional desired dcs config params
                #
                # Minimize risk of large Tx corruption with short archive_timeout
                archive_mode: on
                archive_timeout: 60
                archive_command: timeout 600 wal-g wal-push "%p"

          method: ${patroniBootstrapMethod}

          initdb:
          - data-checksums
          - encoding: UTF8
          - locale: en_US.UTF8

          walg_timeline:
            command: ${packages.clone-with-walg}/bin/clone
            recovery_conf:
              recovery_target_action: promote
              recovery_target_inclusive: false
              # This parameter needs to be a timeline positive integer or special keyword
              recovery_target_timeline: ${patroniBootstrapMethodWalgTimeline}
              restore_command: ${packages.restore-command}/bin/restore "%f" "%p"

          walg_pitr:
            command: ${packages.clone-with-walg}/bin/clone --recovery-target-time="${patroniBootstrapMethodWalgPitrTimestamp}"
            recovery_conf:
              recovery_target_action: promote
              recovery_target_inclusive: false
              # This parameter needs to be in the 'YYYY-MM-DD HH:MM:SS TZ_NAME'
              # where TZ_NAME is PG accepted TZ name, ex: UTC
              recovery_target_time: ${patroniBootstrapMethodWalgPitrTimestamp}
              # PITR may also require specifying the timeline in certain recovery scenarios
              # Ref:
              #  https://www.postgresql.org/docs/12/continuous-archiving.html
              recovery_target_timeline: ${patroniBootstrapMethodWalgPitrTimeline}
              restore_command: ${packages.restore-command}/bin/restore "%f" "%p"

          post_init: ${packages.patroni-callback}/bin/call post_init

          users:
            {{${patroniSecrets.patroniSuper}}}:
              password: {{${patroniSecrets.patroniSuperPass}}}
              options:
                - createrole
                - createdb
            {{${patroniSecrets.patroniRepl}}}:
              password: {{${patroniSecrets.patroniReplPass}}}
              options:
                - replication
            {{${patroniSecrets.patroniRewind}}}:
              password: {{${patroniSecrets.patroniRewindPass}}}

        postgresql:
          authentication:
            replication:
              username: {{${patroniSecrets.patroniRepl}}}
              password: {{${patroniSecrets.patroniReplPass}}}
            superuser:
              username: {{${patroniSecrets.patroniSuper}}}
              password: {{${patroniSecrets.patroniSuperPass}}}
            rewind:
              username: {{${patroniSecrets.patroniRewind}}}
              password: {{${patroniSecrets.patroniRewindPass}}}
          callbacks:
            on_reload:      ${packages.patroni-callback}/bin/call on_reload
            on_restart:     ${packages.patroni-callback}/bin/call on_restart
            on_role_change: ${packages.patroni-callback}/bin/call on_role_change
            on_start:       ${packages.patroni-callback}/bin/call on_start
            on_stop:        ${packages.patroni-callback}/bin/call on_stop
          create_replica_methods:
            - wal_g
            - basebackup
          connect_address: "{{ env "NOMAD_IP_psql" }}:{{ env "NOMAD_PORT_psql" }}"
          data_dir: '${volumeMount}/postgres/patroni'
          listen: "0.0.0.0:${toString psqlPort}"
          parameters:
            archive_mode: on
            archive_timeout: 60
            archive_command: timeout 600 wal-g wal-push "%p"
            log_checkpoints: on
            log_connections: on
            log_destination: stderr
            log_min_messages: info
            log_min_error_statement: info
            log_statement: mod
            password_encryption: scram-sha-256
            ssl: on
            ssl_ca_file: '/run/postgresql/ca.pem'
            ssl_cert_file: '/run/postgresql/cert.pem'
            ssl_key_file: '/run/postgresql/key.pem'
            unix_socket_directories: '/alloc'
          recovery_conf:
            restore_command: ${packages.restore-command}/bin/restore "%f" "%p"
          wal_g:
            command: ${packages.walg-restore}/bin/restore
            threshold_megabytes: 10240
            threshold_backup_size_percentage: 30
            retries: 2
            no_master: 1
            debug: 1

        # Watchdog is not yet compatible from within nomad jobs
        # Ref: https://github.com/hashicorp/nomad/issues/5882
        #
        watchdog:
          mode: automatic
          device: '/soft-watchdog/watchdog'
          safety_margin: -1
        {{end}}
      '';
      destination = patroniYaml;
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
  ];
}
