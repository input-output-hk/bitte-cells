{
  inputs,
  cell,
}: {
  workload-identity-consul = {consulPolicy}: [
    {
      change_mode = "restart";
      data = ''
        {{ with secret "consul/creds/${consulPolicy}" }}
        CONSUL_HTTP_TOKEN={{- .Data.token -}}
        {{ end }}
      '';
      destination = "secrets/consul_token";
      env = true;
    }
  ];
  workload-identity-vault = {vaultPkiPath}: [
    {
      change_mode = "restart";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${vaultPkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.certificate }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/tls/cert.pem";
      splay = "5s";
    }
    {
      change_mode = "restart";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${vaultPkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.private_key }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/tls/key.pem";
      splay = "5s";
    }
    {
      change_mode = "restart";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${vaultPkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.issuing_ca }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/tls/ca.pem";
      splay = "5s";
    }
  ];
}
