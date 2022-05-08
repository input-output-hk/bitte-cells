{
  inputs,
  cell,
}: {
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
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
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
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
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
      left_delimiter = "{{";
      perms = "0644";
      right_delimiter = "}}";
      splay = "5s";
    }
  ];
}
