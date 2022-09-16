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
    "${namespace}"
  ];
}) (l.attrNames computedServiceConfig)
