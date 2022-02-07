{ secretsPath
, consulPath
, rabbitmqConf
, namespace
}:
{
  template = [
    {
      change_mode = "restart";
      data = ''
        {{with secret "${secretsPath}"}}PATH="/bin"
        # Debug params -- comment to disable
        # DEBUG_SLEEP=300

        # Environment references:
        #   https://www.rabbitmq.com/configure.html#customise-environment
        #   https://www.rabbitmq.com/configure.html#supported-environment-variables
        #   https://www.rabbitmq.com/relocate.html
        #   https://erlang.org/doc/man/erl.html
        ERL_CRASH_DUMP="/local/erc_crash.dump"
        HOME="/local"
        LANG="C.UTF-8"
        RABBITMQ_CONFIG_FILE="/secrets/rabbitmq.conf"
        RABBITMQ_CONF_ENV_FILE="/secrets/rabbitmq-env.conf"
        RABBITMQ_ENABLED_PLUGINS_FILE="/local/enabled_plugins"
        RABBITMQ_ERLANG_COOKIE="{{.Data.data.rabbitErlangCookie}}"
        RABBITMQ_ERLANG_COOKIE_PATH="/local/.erlang.cookie"
        RABBITMQ_ADVANCED_CONFIG_FILE="/local/advanced.config"
        RABBITMQ_LOG_BASE="/local/log"
        RABBITMQ_LOGS="-"
        RABBITMQ_MNESIA_BASE="/local/mnesia"
        RABBITMQ_NODENAME="rabbit@{{ env "attr.unique.hostname" }}.node.consul"
        RABBITMQ_USE_LONGNAME="true"

        TERM="xterm-256color"{{end}}
      '';
      destination = "secrets/env.txt";
      env = true;
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "60s";
    }
    {
      change_mode = "restart";
      data = ''
        {{with secret "${secretsPath}"}}# Configuration references:
        #   https://www.rabbitmq.com/configure.html
        #   https://github.com/rabbitmq/rabbitmq-server/blob/v3.8.x/deps/rabbit/docs/rabbitmq.conf.example
        #   https://www.rabbitmq.com/install-generic-unix.html

        # Cluster formation
        cluster_formation.peer_discovery_backend = consul
        cluster_formation.consul.acl_token = {{ with secret "${consulPath}" }}{{ .Data.token }}{{end}}
        cluster_formation.consul.cluster_name = ${namespace}-rabbit
        cluster_formation.consul.host = localhost
        cluster_formation.consul.lock_prefix = service/${namespace}-rabbit
        cluster_formation.consul.port = 8500
        cluster_formation.consul.scheme = http
        cluster_formation.consul.svc = ${namespace}-rabbit
        cluster_formation.consul.svc_addr_auto = true
        cluster_formation.consul.svc_addr_nic = ens5
        cluster_formation.consul.svc_addr_use_nodename = false
        cluster_formation.consul.svc_port = 5671 # TODO: switch to tls
        cluster_formation.consul.svc_ttl = 30
        cluster_formation.consul.deregister_after = 90
        cluster_formation.consul.include_nodes_with_warnings = false
        cluster_formation.consul.lock_timeout = 300
        cluster_formation.consul.lock_prefix = rabbitmq
        cluster_formation.consul.svc_tags.1 = node-{{ env "NOMAD_ALLOC_INDEX" }}

        listeners.ssl.default = 5671
        ssl_options.cacertfile = /secrets/ca-rabbit.pem
        ssl_options.certfile = /secrets/cert-rabbit.pem
        ssl_options.keyfile = /secrets/key-rabbit.pem
        ssl_options.verify = verify_peer
        ssl_options.depth = 1  # the default
        ssl_options.fail_if_no_peer_cert = true  # let's be paranoidly eager

        # Management UI default admin user
        default_user = {{.Data.data.rabbitAdmin}}
        default_pass = {{.Data.data.rabbitAdminPass}}

        # Logging reference:
        #   https://www.rabbitmq.com/logging.html#logging-to-console
        log.console = true
        log.console.level = debug
        log.dir = /local
        log.file = false
        management.http_log_dir = /local{{end}}
        # The following line maintainers the default 40% high watermark of RAM allocation
        vm_memory_high_watermark.absolute = 410MB
      '';
      destination = "${rabbitmqConf}";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "60s";
    }
    {
      change_mode = "restart";
      data = "[rabbitmq_peer_discovery_consul,rabbitmq_prometheus,rabbitmq_management,rabbitmq_management_agent].";
      destination = "local/enabled_plugins";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "30s";
    }
  ];
}
