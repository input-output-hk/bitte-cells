{ pkiPath }:
{
  template = [
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "alt_names=${
        subdomain
      }" "ttl=720h" }}{{ .Data.certificate }}
        {{ range .Data.ca_chain }}{{ . }}
        {{ end }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-rabbit.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "30s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "alt_names=${
        subdomain
      }" "ttl=720h" }}
        {{ .Data.private_key }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/key-rabbit.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "30s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "alt_names=${
        subdomain
      }" "ttl=720h" }}
        {{ .Data.issuing_ca }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/ca-rabbit.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "30s";
    }
  ];
}
