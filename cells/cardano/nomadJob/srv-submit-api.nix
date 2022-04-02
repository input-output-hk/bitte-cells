{
  namespace,
  healthChecks,
}: {
  address_mode = "auto";
  tags = [
    "\${NOMAD_ALLOC_ID}"
  ];
  check = [
    {
      address_mode = "host";
      interval = "1m0s";
      port = "submit";
      timeout = "2s";
      type = "tcp";
    }
  ];
  name = "${namespace}-submit";
  port = "submit";
}
