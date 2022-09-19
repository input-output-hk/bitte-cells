{
  inputs,
  cell,
}: {
  # If your cluster encounters entrypoint or other conflicts with this code,
  # this snippet does not need to be imported directly and a customized version of this can
  # be declared directly in your respective cluster's metal level routing machine.
  routing = {...}: {
    networking.firewall.allowedTCPPorts = [
      # Tempo app default ports
      3200  # tempo httpListenPort default port
      9095  # tempo-grpc grpcListenPort default port
      # Tempo receiver default ports
      4317  # tempo-otlp-grpc receiver default port
      4318  # tempo-otlp-http receiver default port
      9411  # tempo-zipkin receiver default port
      14250 # tempo-jaeger-grpc receiver default port
      14268 # tempo-jaeger-thrift-http default receiver port
      55678 # tempo-opencensus default receiver port
    ];

    # Tempo receiver port references:
    # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/jaegerreceiver
    #
    # However, Nomad does not support UDP checks yet
    # Ref: https://github.com/hashicorp/nomad/issues/14094
    # allowedUDPPorts = [
    #   6831  # tempo jaeger-thrift-compact receiver port
    #   6832  # tempo jaeger-thrift-binary receiver port
    # ];

    # Create entrypoints to match the tempo default cluster service names
    # so that when tempo nomadChart is run, the traefik tags submitted by
    # the job will have matching entrypoints to bind to.
    services.traefik.staticConfigOptions = {
      entryPoints = {
        tempo.address = ":3200";
        tempo-grpc.address = ":9095";
        tempo-otlp-grpc.address = ":4317";
        tempo-otlp-http.address = ":4318";
        tempo-zipkin.address = ":9411";
        tempo-jaeger-grpc.address = ":14250";
        tempo-jaeger-thrift-http.address = ":14268";
        tempo-opencensus.address = ":55678";

        # Per note above, Nomad does not support UDP yet:
        # tempo-jaeger-thrift-compact.address = ":6831";
        # tempo-jaeger-thrift-binary.address = ":6832";
      };
    };
  };
}
