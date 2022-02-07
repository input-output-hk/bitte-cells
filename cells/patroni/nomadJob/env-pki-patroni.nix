{ pkiPath }:
{
  template = [
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.certificate }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-postgres.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.private_key }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-key-postgres.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.issuing_ca }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-ca-postgres.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.certificate }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-patroni.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.private_key }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-key-patroni.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
    {
      change_mode = "signal";
      change_signal = "SIGHUP";
      data = ''
        {{ with $hostIp := (env "attr.unique.network.ip-address") }}
        {{ with secret "${pkiPath}" (printf "common_name=%s" $hostIp) (printf "ip_sans=%s" $hostIp) "ttl=720h" }}
        {{ .Data.issuing_ca }}
        {{ end }}
        {{ end }}
      '';
      destination = "secrets/cert-ca-patroni.pem";
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
  ];
}
