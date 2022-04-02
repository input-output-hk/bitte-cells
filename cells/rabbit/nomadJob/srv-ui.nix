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
      path = "/";
      port = "mgmt";
      protocol = "http";
      timeout = "2s";
      type = "http";
    }
  ];
  name = "${namespace}-rabbit-ui";
  port = "mgmt";
  tags = [
    "\${NOMAD_ALLOC_ID}"
    "${namespace}"
    "ingress"
    "traefik.enable=true"
    "traefik.http.routers.${namespace}-rabbit-ui.rule=Host(`${subdomain}`)"
    "traefik.http.routers.${namespace}-rabbit-ui.entrypoints=https"
    "traefik.http.routers.${namespace}-rabbit-ui.tls=true"
    "traefik.http.routers.${namespace}-rabbit-ui.middlewares=${namespace}-rabbit-ui-ratelimit@consulcatalog"
    "traefik.http.middlewares.${namespace}-rabbit-ui-ratelimit.ratelimit.average=100"
    "traefik.http.middlewares.${namespace}-rabbit-ui-ratelimit.ratelimit.burst=250"
    "traefik.http.middlewares.${namespace}-rabbit-ui-ratelimit.ratelimit.period=1m"
  ];
}
