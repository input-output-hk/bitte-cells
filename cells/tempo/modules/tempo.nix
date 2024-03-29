{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tempo;
  settingsFormat = pkgs.formats.yaml {};
in {
  disabledModules = [ "services/tracing/tempo.nix" ];

  options.services.tempo = {
    enable = mkEnableOption (mdDoc "Grafana Tempo");

    logLevel = mkOption {
      type = types.enum ["debug" "info" "warn" "error"];
      default = "info";
      description = mdDoc ''
        Only log messages with the given severity or above.
        Valid levels: [debug, info, warn, error] (default info)
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to automatically open Tempo httpListenPort and
        grpcListenPort in the firewall as well as any optionally
        enabled Tempo receiver ports.
      '';
    };

    memcachedEnable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Use memcached to improve performance of Tempo trace lookups.
        Redis support as a Tempo cache is still marked experimental.
      '';
    };

    memcachedMaxMB = mkOption {
      type = types.ints.positive;
      default = 1024;
      description = mdDoc ''
        If services.tempo.memcachedEnable is true, use a default maximum of 1 GB RAM.
      '';
    };

    httpListenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = mdDoc "HTTP server listen host.";
    };

    httpListenPort = mkOption {
      type = types.port;
      default = 3200;
      description = mdDoc "HTTP server listen port.";
    };

    grpcListenPort = mkOption {
      type = types.port;
      default = 9095;
      description = mdDoc "gRPC server listen port.";
    };

    receiverOtlpHttp = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Enable OTLP receiver on HTTP, port 4318.";
    };

    receiverOtlpGrpc = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Enable OTLP receiver on gRPC, port 4317.";
    };

    receiverJaegerThriftHttp = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Enable Jaeger thrift receiver on HTTP, port 14268.";
    };

    receiverJaegerGrpc = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Enable Jaeger receiver on gRPC, port 14250.";
    };

    receiverJaegerThriftBinary = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable Jaeger thrift receiver for binary, port 6832.

        NOTE: Default is false as Nomad does not support UDP checks yet
        Ref: https://github.com/hashicorp/nomad/issues/14094
      '';
    };

    receiverJaegerThriftCompact = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable Jaeger thrift receiver on compact, port 6831.

        NOTE: Default is false as Nomad does not support UDP checks yet
        Ref: https://github.com/hashicorp/nomad/issues/14094
      '';
    };

    receiverZipkin = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Enable Zipkin receiver, port 9411.";
    };

    receiverOpencensus = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc "Enable Opencensus receiver, port 55678.";
    };

    receiverKafka = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable Kafta receiver.
        Note: The Tempo service will fail if Tempo cannot reach a Kafka broker.

        See the following refs for configuration details:
        https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kafkareceiver
        https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kafkametricsreceiver
      '';
    };

    logReceivedSpansEnable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable to log every received span to help debug ingestion
        or calculate span error distributions using the logs.
      '';
    };

    logReceivedSpansIncludeAllAttrs = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable to log all attributes of received spans when
        services.tempo.logReceivedSpansEnable is true.
      '';
    };

    logReceivedSpansFilterByStatusError = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable to log received spans by error status when
        services.tempo.logReceivedSpansEnable is true.
      '';
    };

    searchTagsDenyList = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      description = mdDoc ''
        List of string tags that will not be extracted from trace data for search lookups.
        This is a global config that will apply to all tenants.
      '';
    };

    ingesterLifecyclerRingRepl = mkOption {
      type = types.ints.positive;
      default = 1;
      description = mdDoc ''
        Number of replicas of each span to make while pushing to the backend.
      '';
    };

    metricsGeneratorEnableServiceGraphs = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        The metrics-generator processes spans and write metrics using
        the Prometheus remote write protocol.

        This option will enable processing of service graphs from spans.
      '';
    };

    metricsGeneratorEnableSpanMetrics = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        The metrics-generator processes spans and write metrics using
        the Prometheus remote write protocol.

        This option will enable processing of span metrics from spans.
      '';
    };

    metricsGeneratorStoragePath = mkOption {
      type = types.str;
      default = "/local/tempo/storage/wal-metrics";
      description = mdDoc ''
        Path to store the WAL. Each tenant will be stored in its own subdirectory.
      '';
    };

    metricsGeneratorStorageRemoteWrite = mkOption {
      type = types.nullOr (types.listOf types.attrs);
      default = [{url = "http://victoriametrics.service.consul:8428/api/v1/write";}];
      description = mdDoc ''
        A list of remote write endpoints in Prometheus remote_write format:
        https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write

        NOTE: Does not support SRV records.
      '';
    };

    compactorCompactionBlockRetention = mkOption {
      type = types.str;
      default = "336h";
      description = mdDoc "Duration to keep blocks.  Default is 14 days.";
    };

    storageTraceBackend = mkOption {
      type = types.enum ["local" "s3"];
      default = "s3";
      description = mdDoc ''
        The storage backend to use.
      '';
    };

    storageLocalPath = mkOption {
      type = types.str;
      default = "/local/tempo/storage/local";
      description = mdDoc ''
        Where to store state if the backend selected is "local".
      '';
    };

    storageS3Bucket = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Bucket name in s3.  Tempo requires a dedicated bucket since it maintains a top-level
        object structure and does not support a custom prefix to nest within a shared bucket.
      '';
    };

    storageS3Endpoint = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Api endpoint to connect to.  Use AWS S3 or any S3 compatible object storage endpoint.

        As an example, for AWS typically this would be set to: s3.$REGION.amazonaws.com,
        where $REGION is the region the s3 bucket was created in.
      '';
    };

    storageS3AccessCredsEnable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Whether to enable access key ENV VAR usage for static credentials.

        If enabled, a file is expected to exist at location specified by option
        storageS3AccessCredsPath.
      '';
    };

    storageS3AccessCredsPath = mkOption {
      type = types.str;
      default = "/run/keys/tempo";
      description = mdDoc ''
        Specifies the location of an S3 credentials file that Tempo should utilize.

        This file is expected to contain the following substituted lines:

        AWS_ACCESS_KEY_ID=$SECRET_KEY_ID
        AWS_SECRET_ACCESS_KEY=$SECRET_KEY
      '';
    };

    storageS3ForcePathStyle = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable to use path-style requests.
      '';
    };

    storageS3Insecure = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Debugging option for temporary http testing.
      '';
    };

    storageS3InsecureSkipVerify = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Debugging option for temporary https testing.
      '';
    };

    storageTraceWalPath = mkOption {
      type = types.str;
      default = "/local/tempo/storage/wal";
      description = mdDoc ''
        Where to store the head blocks while they are being appended to.
      '';
    };

    searchEnable = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        Enable tempo search.
      '';
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = mdDoc ''
        Extra configuration to pass to Tempo service.
        See https://grafana.com/docs/tempo/latest/configuration/ for available options.
      '';
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = mdDoc ''
        As an alternative to building a working Tempo configuration using the available
        module options, the path to a complete Tempo configuration file may be provided.

        When a path to a complete Tempo configuration file is provided, all Tempo module
        options will be ignored in favor of the Tempo configuration file, with the
        exception of the 'service.tempo.enable' and 'services.tempo.logLevel' options.
      '';
    };

    computedFirewallConfig = mkOption {
      type = types.attrs;
      internal = true;
      default = {
        # Tempo receiver port references:
        # https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md
        # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/jaegerreceiver
        # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/opencensusreceiver
        # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/zipkinreceiver
        allowedTCPPorts = [
          cfg.httpListenPort # default: 3200
          cfg.grpcListenPort # default: 9095
        ]
        ++ optionals cfg.receiverOtlpGrpc [4317]
        ++ optionals cfg.receiverOtlpHttp [4318]
        ++ optionals cfg.receiverZipkin [9411]
        ++ optionals cfg.receiverJaegerGrpc [14250]
        ++ optionals cfg.receiverJaegerThriftHttp [14268]
        ++ optionals cfg.receiverOpencensus [55678]
        ;

        # Tempo receiver port references:
        # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/jaegerreceiver
        allowedUDPPorts = optionals cfg.receiverJaegerThriftCompact [6831]
          ++ optionals cfg.receiverJaegerThriftBinary [6832]
          ;
      };
    };

    computedServiceConfig = mkOption {
      type = types.attrs;
      internal = true;
      default = {
        # Tempo receiver port references -- same as for computedFirewallConfig
        tempo = { port = cfg.httpListenPort; type = "http"; interval = "10s"; timeout = "2s"; path = "/ready"; };
        tempo-grpc = { port = cfg.grpcListenPort; type = "grpc"; interval = "10s"; timeout = "2s"; };
      }
      // optionalAttrs cfg.receiverOtlpGrpc
        { tempo-otlp-grpc = { port = 4317; type = "tcp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverOtlpHttp
        { tempo-otlp-http = { port = 4318; type = "tcp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverZipkin
        { tempo-zipkin = { port = 9411; type = "tcp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverJaegerGrpc
        { tempo-jaeger-grpc = { port = 14250; type = "tcp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverJaegerThriftHttp
        { tempo-jaeger-thrift-http = { port = 14268; type = "tcp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverOpencensus
        { tempo-opencensus = { port = 55678; type = "tcp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverJaegerThriftCompact
        { tempo-jaeger-thrift-compact = { port = 6831; type = "udp"; interval = "10s"; timeout = "2s"; }; }
      // optionalAttrs cfg.receiverJaegerThriftBinary
        { tempo-jaeger-thrift-binary = { port = 6832; type = "udp"; interval = "10s"; timeout = "2s"; }; }
      ;
    };

    computedTempoConfig = mkOption {
      type = types.attrs;
      internal = true;
      default =
        assert asserts.assertMsg
          (cfg.metricsGeneratorEnableServiceGraphs || cfg.metricsGeneratorEnableSpanMetrics -> cfg.metricsGeneratorStorageRemoteWrite != null)
          ''
            Please specify a Prometheus metrics remote write endpoint when using Tempo metrics
            generator services with 'services.tempo.metricsGeneratorStorageRemoteWrite'.
          '';
        assert asserts.assertMsg
          (cfg.storageTraceBackend == "s3" -> cfg.storageS3Bucket != null)
          ''
            Please specify an S3 storage bucket when using the s3 storage backend with
            with 'services.tempo.storageS3Bucket'.
          '';
        assert asserts.assertMsg
          (cfg.storageTraceBackend == "s3" -> cfg.storageS3Endpoint != null)
          ''
            Please specify an S3 storage endpoint when using the s3 storage backend with
            with 'services.tempo.storageS3Endpoint'.
          '';
        recursiveUpdate {
          server = {
            http_listen_address = cfg.httpListenAddress;
            http_listen_port = cfg.httpListenPort;
            grpc_listen_port = cfg.grpcListenPort;
          };

          distributor = {
            receivers = let
              mkTempoReceiver = opt: receiver:
                if opt
                then flip recursiveUpdate receiver
                else flip recursiveUpdate {};
            in pipe {} [
              (mkTempoReceiver cfg.receiverOtlpHttp {otlp.protocols.http = null;})
              (mkTempoReceiver cfg.receiverOtlpGrpc {otlp.protocols.grpc = null;})
              (mkTempoReceiver cfg.receiverJaegerThriftHttp {jaeger.protocols.thrift_http = null;})
              (mkTempoReceiver cfg.receiverJaegerGrpc {jaeger.protocols.grpc = null;})
              (mkTempoReceiver cfg.receiverJaegerThriftBinary {jaeger.protocols.thrift_binary = null;})
              (mkTempoReceiver cfg.receiverJaegerThriftCompact {jaeger.protocols.thrift_compact = null;})
              (mkTempoReceiver cfg.receiverZipkin {zipkin = null;})
              (mkTempoReceiver cfg.receiverOpencensus {opencensus = null;})
              (mkTempoReceiver cfg.receiverKafka {kafka = null;})
            ];

            log_received_spans = {
              enabled = cfg.logReceivedSpansEnable;
              include_all_attributes = cfg.logReceivedSpansIncludeAllAttrs;
              filter_by_status_error = cfg.logReceivedSpansFilterByStatusError;
            };

            search_tags_deny_list = cfg.searchTagsDenyList;
          };

          ingester.lifecycler.ring.replication_factor = cfg.ingesterLifecyclerRingRepl;

          metrics_generator_enabled = cfg.metricsGeneratorEnableServiceGraphs || cfg.metricsGeneratorEnableSpanMetrics;
          metrics_generator.storage = {
            path = cfg.metricsGeneratorStoragePath;
            remote_write = cfg.metricsGeneratorStorageRemoteWrite;
          };
          overrides.metrics_generator_processors = optional cfg.metricsGeneratorEnableServiceGraphs "service-graphs"
            ++ optional cfg.metricsGeneratorEnableSpanMetrics "span-metrics";

          compactor.compaction.block_retention = cfg.compactorCompactionBlockRetention;

          storage.trace =
            {
              backend = cfg.storageTraceBackend;
              local.path = cfg.storageLocalPath;
              wal.path = cfg.storageTraceWalPath;
            }
            // optionalAttrs (cfg.memcachedEnable) {
              cache = "memcached";
              memcached.addresses = let
                inherit (config.services.memcached) listen port;
              in "${listen}:${toString port}";
            }
            // optionalAttrs (cfg.storageTraceBackend == "s3") {
              s3 =
                {
                  bucket = cfg.storageS3Bucket;
                  endpoint = cfg.storageS3Endpoint;

                  # For temporary debug:
                  insecure = cfg.storageS3Insecure;
                  insecure_skip_verify = cfg.storageS3InsecureSkipVerify;

                  # For minio use:
                  forcepathstyle = cfg.storageS3ForcePathStyle;
                }
                // optionalAttrs cfg.storageS3AccessCredsEnable
                {
                  access_key = "\${AWS_ACCESS_KEY_ID}";
                  secret_key = "\${AWS_SECRET_ACCESS_KEY}";
                };
            };

          search_enabled = cfg.searchEnable;
        }
        cfg.extraConfig;
   };
  };
}
