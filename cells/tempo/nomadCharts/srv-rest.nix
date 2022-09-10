{
  namespace,
}:
[
  {
    check = [
      {
        interval = "10s";
        port = "tempo";
        timeout = "2s";
        type = "tcp";
      }
    ];
    name = "tempo";
    port = "tempo";
    tags = [
      "\${NOMAD_ALLOC_ID}"
      "${namespace}"
    ];
  }
  {
    check = [
      {
        interval = "10s";
        port = "tempo-otlp-grpc";
        timeout = "2s";
        type = "tcp";
      }
    ];
    name = "tempo-otlp-grpc";
    port = "tempo-otlp-grpc";
    tags = [
      "\${NOMAD_ALLOC_ID}"
      "${namespace}"
    ];
  }
  {
    check = [
      {
        interval = "10s";
        port = "tempo-jaeger-thrift-http";
        timeout = "2s";
        type = "tcp";
      }
    ];
    name = "tempo-jaeger-thrift-http";
    port = "tempo-jaeger-thrift-http";
    tags = [
      "\${NOMAD_ALLOC_ID}"
      "${namespace}"
    ];
  }
]
