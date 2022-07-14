{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;
  inherit (inputs.cells._utils.packages) norouter;

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
        norouter
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
        contents = (oci.contents or []) ++ [debug-bin norouter];
      };

  mkAlerts = let
    allTrue = lib.all lib.id;

    lintAlerts = n: v: let
      check = checkFn: msg: nvp:
        if checkFn
        then v
        else throw msg;
      nvp = lib.nameValuePair n v;
    in
      lib.pipe nvp [
        (check (nvp.value ? "groups") ''Declarative alert file does not contain "groups" attribute: ${nvp.name}'')

        (check (builtins.isList nvp.value.groups) ''Declarative alert file contains a "groups" attribute that is not a list: ${nvp.name}'')

        (check (
          if (builtins.length nvp.value.groups) == 0
          then (builtins.trace ''WARN: Declarative alert file has no group list items: ${nvp.name}'' true)
          else true
        ) "Undefined error")

        (check (allTrue (map (group:
            if group ? "name"
            then true
            else false)
          nvp.value.groups))
          ''Declarative alert file has a missing "name" attribute in one of the group list items: ${nvp.name}'')

        (check (allTrue (map (group:
            if group ? "rules"
            then true
            else false)
          nvp.value.groups))
          ''Declarative alert file has a missing "rules" attribute in one of the group list items: ${nvp.name}'')

        (check (allTrue (map (group: builtins.isList group.rules) nvp.value.groups))
          ''Declarative alert file contains a group list item with a "rules" attribute that is not a list: ${nvp.name}'')

        (check (allTrue (map (
            group:
              if (builtins.length group.rules) == 0
              then (builtins.trace ''WARN: Declarative alert file has a group list item with no rules: ${nvp.name}'' true)
              else true
          )
          nvp.value.groups)) "Undefined error")
      ];

    mkAlertType = ds: alertSet:
      lib.pipe alertSet [
        (lib.filterAttrs (_: v: v.datasource == ds))
        (lib.mapAttrs' sanitizeAlertAttrs)
        (lib.mapAttrs toAlertFilePrep)
        (lib.mapAttrs lintAlerts)
        (lib.mapAttrs (_: v: builtins.toJSON v))
        (lib.mapAttrs (n: v: builtins.toFile n v))
        (lib.mapAttrs' (toKvAlertAttrs ds))
        (let resources = kvAlertAttrs: {vault_generic_secret = kvAlertAttrs;}; in resources)
        # (let pp = a: builtins.trace (builtins.toJSON a) a; in pp)
      ];

    mkAlertResources = alertSet: lib.foldl (acc: ds: lib.recursiveUpdate acc (mkAlertType ds alertSet)) {} ["vm" "loki"];

    sanitizeAlertAttrs = n: v: lib.nameValuePair (normalizeTfName n) ((builtins.removeAttrs v ["datasource"]) // {name = normalizeTfName n;});

    toAlertFilePrep = _: v: {groups = lib.singleton v;};

    toKvAlertAttrs = ds: n: v:
      lib.nameValuePair "vmalert_${ds}_${n}" {
        path = "kv/system/alerts/${ds}/${n}";
        data_json = terralibVar ''file("${v}")'';
        delete_all_versions = true;
      };
  in
    mkAlertResources;

  mkDashboards = let
    mkDashboardType = dashboardSet:
      lib.pipe dashboardSet [
        (lib.mapAttrs (n: v: builtins.toFile n v))
        (lib.mapAttrs' toKvDashboardAttrs)
        (let resources = kvDashboardAttrs: {vault_generic_secret = kvDashboardAttrs;}; in resources)
        # (let pp = a: builtins.trace (builtins.toJSON a) a; in pp)
      ];

    mkDashboardResources = dashboardSet: mkDashboardType dashboardSet;

    toKvDashboardAttrs = n: v:
      lib.nameValuePair "grafana_dashboard_${normalizeTfName n}" {
        path = "kv/system/dashboards/${normalizeTfName n}";
        data_json = terralibVar ''file("${v}")'';
        delete_all_versions = true;
      };
  in
    mkDashboardResources;

  mkMonitoring = alertSet: dashboardSet: lib.recursiveUpdate (mkAlerts alertSet) (mkDashboards dashboardSet);

  normalizeTfName = lib.replaceStrings ["/" "-" "."] ["_" "_" "_"];

  terralibVar = v: "\${${v}}";
}
