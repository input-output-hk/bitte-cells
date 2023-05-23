{
  namespace,
}: {
  address_mode = "host";
  check = [
    {
      name = "isLive";
      address_mode = "host";
      interval = "10s";
      method = "GET";
      path = "/liveness";
      port = "patroni";
      protocol = "https";
      timeout = "2s";
      type = "http";
    }
    {
      name = "isRunning";
      address_mode = "host";
      args = [];
      command = "/bin/healthcheck";
      interval = "10s";
      task = "patroni";
      timeout = "5s";
      type = "script";
    }
  ];
  name = "${namespace}-patroni-rest";
  port = "patroni";
  tags = [
    "\${NOMAD_ALLOC_ID}"
    namespace
  ];
}
