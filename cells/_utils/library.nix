{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;
  n2c = inputs.n2c.packages.nix2container;
in rec {
  mkDebugOCI = with nixpkgs.pkgsStatic;
    entrypoint: oci: let
      iog-debug-banner = runCommandNoCC "iog-debug-banner" {} ''
        ${figlet}/bin/figlet -f banner "IOG Debug" > $out
      '';
      debug-tools = [
        bashInteractive.out
        busybox
        curl.bin
        jq.bin
      ];
      debug-bin = writeShellApplication {
        name = "debug";
        runtimeInputs =
          entrypoint.runtimeInputs
          or []
          ++ entrypoint.debugInputs or []
          ++ debug-tools;
        text = with nixpkgs.pkgsStatic; ''
          # shellcheck source=/dev/null
          # source ''${cacert}/nix-support/setup-hook

          cat ${iog-debug-banner}
          echo
          echo "=========================================================="
          echo "This debug shell contains the runtime environment and "
          echo "debug dependencies of the entrypoint."
          echo "To inspect the entrypoint(s) run:"
          echo "cat ${entrypoint}/bin/*"
          echo "=========================================================="
          echo
          exec bash "$@"
        '';
      };
    in
      oci
      // {
        contents = (oci.contents or []) ++ [debug-bin];
      };

  mkAlerts = let
    mkAlertType = ds: alertSet: lib.pipe alertSet [
      (lib.filterAttrs (n: v: v.datasource == ds))
      (lib.mapAttrs' sanitizeAlertAttrs)
      (toAlertFilePrep ds)
      (lib.mapAttrs (n: v: builtins.toFile n v))
      (lib.mapAttrs' (toKvAlertAttrs ds))
      (let resources = kvAlertAttrs: { vault_generic_secret =  kvAlertAttrs; }; in resources)
      # (let pp = a: builtins.trace (builtins.toJSON a) a; in pp)
    ];

    mkAlertResources = alertSet: lib.foldl (acc: ds: lib.recursiveUpdate acc (mkAlertType ds alertSet)) {} [ "vm" "loki" ];

    sanitizeAlertAttrs = n: v: lib.nameValuePair (normalizeTfName n) ((builtins.removeAttrs v [ "datasource" ]) // { name = normalizeTfName n; });

    toAlertFilePrep = ds: rules: lib.mapAttrs' (n: v: lib.nameValuePair "vmalert_${ds}_${n}" (
      builtins.toJSON ( { groups = lib.singleton v; })
    )) rules;

    toKvAlertAttrs = ds: n: v: lib.nameValuePair n ({ path = "kv/system/alerts/${ds}/${n}"; data_json = terralibVar ''file("${v}")''; delete_all_versions = true; });
  in mkAlertResources;

  mkDashboards = let
    mkDashboardType = dashboardSet: lib.pipe dashboardSet [
      (lib.mapAttrs' sanitizeDashboardAttrs)
      (lib.mapAttrs (n: v: builtins.toFile n v))
      (lib.mapAttrs' toKvDashboardAttrs)
      (let resources = kvDashboardAttrs: { vault_generic_secret =  kvDashboardAttrs; }; in resources)
      # (let pp = a: builtins.trace (builtins.toJSON a) a; in pp)
    ];

    mkDashboardResources = dashboardSet: mkDashboardType dashboardSet;

    sanitizeDashboardAttrs = n: v: lib.nameValuePair "grafana_dashboard_${normalizeTfName n}" v;

    toKvDashboardAttrs = n: v: lib.nameValuePair n ({ path = "kv/system/dashboards/${n}"; data_json = terralibVar ''file("${v}")''; delete_all_versions = true; });
  in mkDashboardResources;

  mkMonitoring = alertSet: dashboardSet: lib.recursiveUpdate (mkAlerts alertSet) (mkDashboards dashboardSet);

  normalizeTfName = lib.replaceStrings ["/" "-" "."] ["_" "_" "_"];

  terralibVar = v: "\${${v}}";
}
