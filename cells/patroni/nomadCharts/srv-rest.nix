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
    namespace
    "ingress"
  ];
}
