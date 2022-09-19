{
  l,
  namespace,
  computedServiceConfig,
}:

map (service: {
  check = [
    ({
      port = service;
      type = computedServiceConfig.${service}.type;
      interval = computedServiceConfig.${service}.interval;
      timeout = computedServiceConfig.${service}.timeout;
    }
    // l.optionalAttrs (computedServiceConfig.${service} ? "path")
    { path = computedServiceConfig.${service}.path; })
  ];
  name = service;
  port = service;
  tags = [
    "\${NOMAD_ALLOC_ID}"
    # A namespace tag is included, but tempo requires full control of a bucket
    # and so with this initial implementation, one tempo service will provide
    # service for all namespaces in the cluster.  Traces can include namespace
    # tags so that namespace trace granularity is not lost.  Thus, the namespace
    # parameter is not included in the traefik tags below.  This will also aid
    # with grafana tempo integration while grafana is still a metal service.
    "${namespace}"
    "ingress"
    "traefik.enable=true"
    # Initially treat all tempo services generically, creating simple,
    # forwarding tcp proxies and allow client and server to negotiate specific
    # protocol details directly, as some tempo endpoints use http(s), others grpc,
    # and others tcp.  Initially, a non-intervening tcp proxy will allow all types,
    # until we want to customize endpoints more specifically for each specific receiver.
    "traefik.tcp.routers.${service}.service=${service}"
    "traefik.tcp.routers.${service}.entrypoints=${service}"
    # As we will initially use a forwarding tcp proxy, we do not wish to use SNI.
    # Hence we might expect not enabling the following lines would be what we need:
    #
    # "traefik.tcp.routers.${service}.rule=HostSNI(`*`)"
    # "traefik.tcp.routers.${service}.tls.passthrough=true"
    #
    # However, removing the above SNI lines above generates an "Empty rule" error
    # for a TCP router, and these are the only rules tcp only routers have available.
    # So, we will enable it to avoid the traefik "Empty rule" error, but then also
    # explicitly set tls=false so that it exists, but is effectively a no-op.
    "traefik.tcp.routers.${service}.rule=HostSNI(`*`)"
    "traefik.tcp.routers.${service}.tls=false"
    # The tls=false tells traefik tcp traffic should be sent unterminated and untouched
    # through traefik, leaving handshake and encryption to the client and server.
    # The downside to this is that without SNI it is also unrouted, meaning that one
    # reserved entrypoint per database is required.
  ];
}) (l.attrNames computedServiceConfig)
