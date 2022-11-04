{
  inputs,
  cell,
}: {
  workload-identity-vault-consul = {consulRolePath}: [
    {
      change_mode = "restart";
      data = ''
        {{ with secret "${consulRolePath}" }}
        CONSUL_HTTP_TOKEN={{- .Data.token }}
        CONSUL_HTTP_ADDR="http://172.17.0.1:8500"
        VAULT_ADDR="http://172.17.0.1:8200"
        {{ end }}
      '';
      destination = "secrets/consul_token";
      env = true;
    }
  ];
  workload-identity-vault = {vaultPkiPath, ttl ? "720h", change_mode ? "restart", change_signal ? "SIGHUP", splay ? "5s"}: let
    withCertSecret = template: ''
      {{- define "ipToHex" }}
        {{- range $part := split "." . }}
          {{- $part | parseInt | printf "%02x" }}
        {{- end }}
      {{- end }}
      {{- with $hostIp := (env "attr.unique.network.ip-address") }}
        {{- $consulDC := (env "attr.consul.datacenter") }}
        {{- $consulDNS := (printf "%s.addr.%s.consul" (executeTemplate "ipToHex" $hostIp) $consulDC) }}
        {{- with secret "${vaultPkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) (printf "alt_names=%s" $consulDNS) "ttl=${ttl}" }}
      ${template}
        {{- end }}
      {{- end }}
    '';
  in [
    {
      inherit change_mode change_signal splay;
      data = withCertSecret ''
        {{- .Data.certificate }}
      '';
      destination = "secrets/tls/cert.pem";
    }
    {
      inherit change_mode change_signal splay;
      data = withCertSecret ''
        {{- .Data.private_key }}
      '';
      destination = "secrets/tls/key.pem";
    }
    {
      inherit change_mode change_signal splay;
      data = withCertSecret ''
        {{- range $cert := .Data.ca_chain }}
        {{ $cert }}
        {{- end }}
      '';
      destination = "secrets/tls/ca.pem";
    }
  ];
}
