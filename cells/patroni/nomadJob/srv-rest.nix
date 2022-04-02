{
  namespace,
  subdomain,
}: {
  address_mode = "host";
  check = [
    {
      address_mode = "host";
      interval = "10s";
      method = "GET";
      path = "/liveness";
      port = "patroni";
      protocol = "https";
      timeout = "2s";
      type = "http";
    }
  ];
  name = "${namespace}-patroni-rest";
  port = "patroni";
  tags = [
    "\${NOMAD_ALLOC_ID}"
    "${namespace}"
    "ingress"
    "traefik.enable=true"
    "traefik.http.services.${namespace}-patroni-rest-api.loadbalancer.serverstransport=patroni-rest-api@file"
    "traefik.http.services.${namespace}-patroni-rest-api.loadbalancer.server.scheme=https"
    "traefik.http.routers.${namespace}-patroni-rest-api.rule=Host(`${subdomain}`)"
    "traefik.http.routers.${namespace}-patroni-rest-api.entrypoints=https"
    "traefik.http.routers.${namespace}-patroni-rest-api.tls=true"
    "traefik.http.routers.${namespace}-patroni-rest-api.middlewares=${namespace}-patroni-rest-api-ratelimit@consulcatalog"
    "traefik.http.middlewares.${namespace}-patroni-rest-api-ratelimit.ratelimit.average=100"
    "traefik.http.middlewares.${namespace}-patroni-rest-api-ratelimit.ratelimit.burst=250"
    "traefik.http.middlewares.${namespace}-patroni-rest-api-ratelimit.ratelimit.period=1m"
  ];
}
