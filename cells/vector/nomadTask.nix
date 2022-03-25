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
                  hydrateLabels = ''
                    .nomad_alloc_id = get_env_var!("NOMAD_ALLOC_ID")
                    .nomad_alloc_index = get_env_var!("NOMAD_ALLOC_INDEX")
                    .nomad_alloc_name = get_env_var!("NOMAD_ALLOC_NAME")
                    .nomad_group_name = get_env_var!("NOMAD_GROUP_NAME")
                    .nomad_job_name = get_env_var!("NOMAD_JOB_NAME")
                    .nomad_namespace = get_env_var!("NOMAD_NAMESPACE")
                    .nomad_region = get_env_var!("NOMAD_REGION")
                  '';
                in {
                  transform_stderr = {
                    inputs = ["source_stderr"];
                    type = "remap";
                    source =
                      hydrateLabels
                      + ''
                        .source = "stderr"
                        .nomad_task_name = parse_regex!(.file, r'/(?P<task>.+)\.std(out|err)\.\d+$').task
                      '';
                  };
                  transform_stdout = {
                    inputs = ["source_stdout"];
                    type = "remap";
                    source =
                      hydrateLabels
                      + ''
                        .source = "stdout"
                        .nomad_task_name = parse_regex!(.file, r'/(?P<task>.+)\.std(out|err)\.\d+$').task
                      '';
                  };
                  transform_prom = {
                    type = "remap";
                    inputs = ["prom"];
                    source = ''
                      .tags.namespace = "${namespace}"
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
                    codec = "text";
                    timestamp_format = "rfc3339";
                    only_fields = ["message"];
                  };
                  labels = {
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
