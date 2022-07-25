{
  inputs,
  cell,
}: {
  bitte-cells-patroni = {
    datasource = "vm";
    rules = [
      {
        alert = "PatroniClusterUnlocked";
        expr = "patroni_cluster_unlocked > 0";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Patroni cluster has been unlocked in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }} for more than 5 minutes.'';
          summary = "[Bitte-cells] Patroni cluster is unlocked in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }}";
        };
      }
      {
        alert = "PatroniDcsMissing";
        expr = "rate(patroni_dcs_last_seen)[1m] == 0";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Patroni cluster has not checked in with the DCS in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }} for more than 5 minutes.'';
          summary = "[Bitte-cells] Patroni cluster has not checked in with the DCS in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }}";
        };
      }
      {
        alert = "PatroniLeaderMissing";
        expr = "sum by (namespace) (patroni_master) < 1";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Patroni cluster in namespace {{ $labels.namespace }} has had no leader running for more than 5 minutes.'';
          summary = "[Bitte-cells] Patroni cluster in namespace {{ $labels.namespace }} has no leader running";
        };
      }
      {
        alert = "PatroniMemberMissing";
        expr = "sum by (namespace) (patroni_postgres_running) < 3";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Patroni cluster in namespace {{ $labels.namespace }} has had only {{ $value }} member(s) running for more than 5 minutes.'';
          summary = "[Bitte-cells] Patroni cluster in namespace {{ $labels.namespace }} has less than three members running";
        };
      }
      {
        alert = "PatroniReplicaMissing";
        expr = "sum by (namespace) (patroni_replica) == 0";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Patroni cluster in namespace {{ $labels.namespace }} has had no replicas available for more than 5 minutes.'';
          summary = "[Bitte-cells] Patroni cluster in namespace {{ $labels.namespace }} has no replicas available";
        };
      }
      {
        alert = "PatroniTimelineIncreasing";
        expr = "sum_over_time(rate(patroni_postgres_timeline)[1h]) > 2";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            The patroni postgres timeline has increased by an average of {{ $value }} timelines
             over the past hour in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }}.'';
          summary = "[Bitte-cells] Patroni timeline is increasing rapidly in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }}";
        };
      }
      {
        alert = "PatroniXlogPaused";
        expr = "patroni_xlog_paused > 0";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Patroni cluster has an xlog paused in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }} for more than 5 minutes.'';
          summary = "[Bitte-cells] Patroni cluster has an xlog paused in namespace {{ $labels.namespace }} on allocation {{ $labels.nomad_alloc_name }}";
        };
      }
    ];
  };
}
