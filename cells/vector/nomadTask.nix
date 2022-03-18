{
  inputs,
  cell,
}: let
  inherit (cell) oci-images;
  # OCI-Image Namer
  ociNamer = oci: "${oci.imageName}:${oci.imageTag}";
in {
  default = {endpoints}: {
    task.vector = {
      driver = "docker";
      lifecycle = {
        sidecar = true;
      };
      config.image = ociNamer oci-images.default;
      config.args = ["--config" "/local/vector/default.toml"];
      template = [
        {
          destination = "local/vector/default.toml";
          left_delimiter = "<<";
          right_delimiter = ">>";
          data = ''
            data_dir = "local"
            timezone = "UTC"

            [sinks]
            [sinks.loki]
            endpoint = "http://172.16.0.20:3100"
            inputs = ["transform_stdout", "transform_stderr"]
            type = "loki"

            [sinks.loki.encoding]
              codec = "text"
              timestamp_format = "rfc3339"
              only_fields = ["message"]

            [sinks.loki.labels]
            nomad_alloc_id    = "<<env "NOMAD_ALLOC_ID">>"
            nomad_alloc_index = "<<env "NOMAD_ALLOC_INDEX">>"
            nomad_alloc_name  = "<<env "NOMAD_ALLOC_NAME">>"
            nomad_group_name  = "<<env "NOMAD_GROUP_NAME">>"
            nomad_job_id      = "<<env "NOMAD_ALLOC_JOB_ID">>"
            nomad_job_name    = "<<env "NOMAD_JOB_NAME">>"
            nomad_namespace   = "<<env "NOMAD_NAMESPACE">>"
            nomad_region      = "<<env "NOMAD_REGION">>"
            nomad_task_name   = "<<env "NOMAD_TASK_NAME" >>"
            source = "{{source}}"

            [sinks.prometheus]
            endpoint = "http://172.16.0.20:8428/api/v1/write"
            inputs = ["prom"]
            type = "prometheus_remote_write"

            [sources]
            [sources.prom]
            endpoints = ${builtins.toJSON endpoints}
            scrape_interval_secs = 10
            type = "prometheus_scrape"

            [sources.source_stderr]
            ignore_older_secs = 300
            include = ["/alloc/logs/*.stderr.[0-9]*"]
            line_delimiter = "\r\n"
            read_from = "beginning"
            type = "file"

            [sources.source_stdout]
            ignore_older_secs = 300
            include = ["/alloc/logs/*.stdout.[0-9]*"]
            line_delimiter = "\r\n"
            read_from = "beginning"
            type = "file"

            [transforms]
            [transforms.transform_stderr]
            inputs = ["source_stderr"]
            source = ".source = \"stderr\""
            type = "remap"

            [transforms.transform_stdout]
            inputs = ["source_stdout"]
            source = ".source = \"stdout\""
            type = "remap"
          '';
        }
      ];
    };
  };
}
