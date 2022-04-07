{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge;
  inherit (cell) oci-images;
  # OCI-Image Namer
  ociNamer = oci: "${oci.imageName}:${oci.imageTag}";
in {
  default = {
    endpoints,
    namespace,
    extra ? {},
  }: {
    task.vector = {
      driver = "docker";
      lifecycle = {
        sidecar = true;
      };
      config.image = ociNamer oci-images.default;
      config.args = ["--config" "/local/vector/default.json"];
      template = [
        {
          destination = "local/vector/default.json";
          left_delimiter = "<<";
          right_delimiter = ">>";
          data = with data-merge;
            builtins.toJSON (
              # CONFIGURATION
              merge {
                data_dir = "local";
                timezone = "UTC";
                sources.prom = {
                  inherit endpoints;
                  scrape_interval_secs = 10;
                  type = "prometheus_scrape";
                  instance_tag = "instance";
                  endpoint_tag = "endpoint";
                };
                sources.source_stderr = {
                  ignore_older_secs = 300;
                  include = ["/alloc/logs/*.stderr.[0-9]*"];
                  line_delimiter = "\n";
                  read_from = "beginning";
                  type = "file";
                  max_line_bytes = 8192;
                };
                sources.source_stdout = {
                  ignore_older_secs = 300;
                  include = ["/alloc/logs/*.stdout.[0-9]*"];
                  line_delimiter = "\n";
                  read_from = "beginning";
                  type = "file";
                };
                transforms = let
                  # Not all ingested logs will include a native timestamp, and while Loki ingested logs
                  # do have a timestamp made available by Grafana as .ts and .tsNs, these do not appear
                  # to be accessible for display in an expected manner, ex: line_format.  We'll add a
                  # vector log parse timestamp here to ensure we have one for display if needed.
                  hydrateLabels = ''
                    .nomad_alloc_id = get_env_var!("NOMAD_ALLOC_ID")
                    .nomad_alloc_index = get_env_var!("NOMAD_ALLOC_INDEX")
                    .nomad_alloc_name = get_env_var!("NOMAD_ALLOC_NAME")
                    .nomad_group_name = get_env_var!("NOMAD_GROUP_NAME")
                    .nomad_job_name = get_env_var!("NOMAD_JOB_NAME")
                    .nomad_namespace = get_env_var!("NOMAD_NAMESPACE")
                    .nomad_region = get_env_var!("NOMAD_REGION")
                    .time = now()
                  '';
                in {
                  # Since there will be a mix of log types ingested from both stdout and stderr depending
                  # on job, the ingested logs could be parsed for type (json, clf, logfmt, syslog) and
                  # the parsed output structure merged back to top level, falling back to plaintext
                  # ingestion if parsing for common types fails.  However, this expectedly appears to have
                  # unpredictable results and merge structure.
                  #
                  # Alternatively, we could parse as suggested above and merge the parsed structured output
                  # into a new static key value, such as `structured`.  However, this will double bandwidth
                  # and storage consumption, not to mention the CPU overhead of additional parsing.
                  #
                  # Just ingesting logs as plaintext without additional parsing will give us predictable
                  # top level json structure in Loki and require minimal CPU, bandwidth and storage.
                  # We can then parse further on the .message key in logQL queries as needed in Loki.
                  transform_stderr = {
                    inputs = ["source_stderr"];
                    type = "remap";
                    source =
                      hydrateLabels
                      + ''
                        .source = "stderr"
                        .nomad_task_name = parse_regex!(.file, r'(.*/)*(?P<task>.+)\.stderr\.\d+$').task
                      '';
                  };
                  transform_stdout = {
                    inputs = ["source_stdout"];
                    type = "remap";
                    source =
                      hydrateLabels
                      + ''
                        .source = "stdout"
                        .nomad_task_name = parse_regex!(.file, r'(.*/)*(?P<task>.+)\.stdout\.\d+$').task
                      '';
                  };
                  transform_prom = {
                    type = "remap";
                    inputs = ["prom"];
                    source = ''
                      .tags.namespace = "${namespace}"
                      .tags.nomad_alloc_name = get_env_var!("NOMAD_ALLOC_NAME")
                    '';
                  };
                };
                sinks.prometheus = {
                  endpoint = "http://172.16.0.20:8428/api/v1/write";
                  inputs = ["transform_prom"];
                  type = "prometheus_remote_write";
                };
                sinks.loki = {
                  endpoint = "http://172.16.0.20:3100";
                  inputs = ["transform_stdout" "transform_stderr"];
                  type = "loki";
                  encoding = {
                    # Codec must be "json" to include the remap transform json in the Loki push payload
                    codec = "json";
                    timestamp_format = "rfc3339";

                    # Remove fields we are using as Loki labels -- no need to include them twice
                    # since they are already filterable at the label level.
                    #
                    # Leave nomad_alloc_id as a log key rather than a label since unique values may
                    # be high in a large cluster deployment, and these other labels should already
                    # offer unique stream identification.  Filtering on nomad_alloc_id is available
                    # via logQL.
                    except_fields = [
                      "agent"
                      "codec"
                      "nomad_alloc_index"
                      "nomad_alloc_name"
                      "nomad_group_name"
                      "nomad_job_name"
                      "nomad_namespace"
                      "nomad_region"
                      "nomad_task_name"
                      "source"
                    ];
                  };
                  labels = {
                    # Allow easy filtering for vector logs
                    agent = "vector";

                    # LogQL can filter for only parseable json with: ... | __error__ != "JSONParserError"
                    # but this allows for easy to remember json filtering.
                    codec = "json";

                    # Label cardinality must be high enough to uniquely identify a stream and avoid out of order logs errors
                    # https://grafana.com/docs/loki/latest/best-practices/
                    #
                    # Check cardinality on a Loki server with:
                    # logcli series --analyze-labels '{}'
                    #
                    # Loki >= 2.4.0 no longer requires strict stream time ordering by default,
                    # but to avoid confusing log timelines from unintentionally merged log streams,
                    # it may be best to leave strict ordering enforced going forward.
                    #
                    # Due to higher cardinality, nomad_alloc_id is removed as a label compared to
                    # nomad_alloc_name.  See note above except_fields attr for additional comment.
                    nomad_alloc_index = "{{nomad_alloc_index}}";
                    nomad_alloc_name = "{{nomad_alloc_name}}";
                    nomad_group_name = "{{nomad_group_name}}";
                    nomad_job_name = "{{nomad_job_name}}";
                    nomad_namespace = "{{nomad_namespace}}";
                    nomad_region = "{{nomad_region}}";
                    nomad_task_name = "{{nomad_task_name}}";
                    source = "{{source}}";
                  };
                };
              }
              extra
            );
        }
      ];
    };
  };
}
