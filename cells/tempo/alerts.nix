{
  inputs,
  cell,
}: {
  bitte-cells-tempo = {
    datasource = "vm";
    rules = [
      {
        alert = "TempoRequestErrors";
        expr = ''
          100 * sum(rate(tempo_request_duration_seconds_count{status_code=~"5.."}[1m])) by (route) /
          sum(rate(tempo_request_duration_seconds_count[1m])) by (route) > 10'';
        for = "15m";
        annotations = {
          summary = ''{{ $labels.nomad_alloc_name }} {{ $labels.route }} is experiencing {{ printf "%.2f" $value }}% errors in the past 15 minutes'';
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoRequestErrors";
        };
        labels.severity = "critical";
      }
      {
        alert = "TempoRequestLatency";
        expr = ''route:tempo_request_duration_seconds:99quantile{route!~"metrics|/frontend.Frontend/Process|debug_pprof"} > 3'';
        for = "15m";
        labels = {severity = "critical";};
        annotations = {
          summary = ''{{ $labels.nomad_alloc_name }} {{ $labels.route }} is experiencing {{ printf "%.2f" $value }}s 99th percentile latency for the past 15 minutes.'';
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoRequestLatency";
        };
      }
      {
        alert = "TempoCompactorUnhealthy";
        expr = ''max(cortex_ring_members{state="Unhealthy", name="compactor"}) > 0'';
        for = "15m";
        labels.severity = "critical";
        annotations = {
          summary = ''There are {{ printf "%f" $value }} unhealthy compactor(s) in the past 15 minutes for {{ $labels.nomad_alloc_name }}.'';
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoCompactorUnhealthy";
        };
      }
      {
        alert = "TempoDistributorUnhealthy";
        expr = ''max(cortex_ring_members{state="Unhealthy", name="distributor"}) > 0'';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          summary = ''There are {{ printf "%f" $value }} unhealthy distributor(s) in the past 15 minutes for {{ $labels.nomad_alloc_name }}.'';
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoDistributorUnhealthy";
        };
      }
      {
        alert = "TempoCompactionsFailing";
        expr = ''sum(increase(tempodb_compaction_errors_total[1h])) > 2 and sum(increase(tempodb_compaction_errors_total[5m])) > 0'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          summary = "Greater than 2 compactions have failed in the past hour on {{ $labels.nomad_alloc_name }}.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoCompactionsFailing";
        };
      }
      {
        alert = "TempoIngesterFlushesUnhealthy";
        expr = ''sum(increase(tempo_ingester_failed_flushes_total[1h])) > 2 and sum(increase(tempo_ingester_failed_flushes_total[5m])) > 0'';
        for = "5m";
        labels.severity = "warning";
        annotations = {
          summary = "Greater than 2 flush retries have occurred in the past hour on {{ $labels.nomad_alloc_name }}.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoIngesterFlushesFailing";
        };
      }
      {
        alert = "TempoIngesterFlushesFailing";
        expr = ''sum(increase(tempo_ingester_flush_failed_retries_total[1h])) > 2 and sum(increase(tempo_ingester_flush_failed_retries_total[5m])) > 0'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          summary = "Greater than 2 flush retries have failed in the past hour on {{ $labels.nomad_alloc_name }}.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoIngesterFlushesFailing";
        };
      }
      {
        alert = "TempoPollsFailing";
        expr = ''sum(increase(tempodb_blocklist_poll_errors_total[1h])) > 2 and sum(increase(tempodb_blocklist_poll_errors_total[5m])) > 0'';
        labels.severity = "critical";
        annotations = {
          summary = "Greater than 2 polls have failed in the past hour on {{ $labels.nomad_alloc_name }}.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoPollsFailing";
        };
      }
      {
        alert = "TempoTenantIndexFailures";
        expr = ''sum(increase(tempodb_blocklist_tenant_index_errors_total[1h])) > 2 and sum(increase(tempodb_blocklist_tenant_index_errors_total[5m])) > 0'';
        labels.severity = "critical";
        annotations = {
          summary = "Greater than 2 tenant index failures in the past hour on {{ $labels.nomad_alloc_name }}.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoTenantIndexFailures";
        };
      }
      {
        alert = "TempoNoTenantIndexBuilders";
        expr = ''sum(tempodb_blocklist_tenant_index_builder) == 0 and max(tempodb_blocklist_length) > 0'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          summary = "No tenant index builders for tenant {{ $labels.tenant }} over the past 5 minutes on {{ $labels.nomad_alloc_name }}. Tenant index will quickly become stale.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoNoTenantIndexBuilders";
        };
      }
      {
        alert = "TempoTenantIndexTooOld";
        expr = ''max(tempodb_blocklist_tenant_index_age_seconds) > 600'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          summary = "Tenant index age is 600 seconds old for tenant {{ $labels.tenant }} on {{ $labels.nomad_alloc_name }}.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoTenantIndexTooOld";
        };
      }
      {
        alert = "TempoBadOverrides";
        expr = ''sum(tempo_runtime_config_last_reload_successful == 0)'';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          summary = "{{ $labels.nomad_alloc_name }} failed to reload overrides.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoBadOverrides";
        };
      }
      {
        alert = "TempoProvisioningTooManyWrites";
        expr = ''avg(rate(tempo_ingester_bytes_received_total[1m])) / 1024 / 1024 > 30'';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          summary = "Ingesters in {{ $labels.cluster }}/{{ $labels.namespace }} on {{ $labels.nomad_alloc_name }} are receiving more data/second than desired for the past 15 minutes.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoProvisioningTooManyWrites";
        };
      }
      {
        alert = "TempoCompactorsTooManyOutstandingBlocks";
        expr = ''sum(tempodb_compaction_outstanding_blocks) > 100'';
        for = "6h";
        labels.severity = "warning";
        annotations = {
          summary = "There are too many outstanding compaction blocks for tenant {{ $labels.tenant }} on {{ $labels.nomad_alloc_name }} for the past 6 hours, increase compactor's CPU or add more compactors.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoCompactorsTooManyOutstandingBlocks";
        };
      }
      {
        alert = "TempoCompactorsTooManyOutstandingBlocks";
        expr = ''sum(tempodb_compaction_outstanding_blocks) > 250'';
        for = "24h";
        labels.severity = "critical";
        annotations = {
          summary = "There are too many outstanding compaction blocks for tenant {{ $labels.tenant }} on {{ $labels.nomad_alloc_name }} for the past 24 hours, increase compactor's CPU or add more compactors.";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoCompactorsTooManyOutstandingBlocks";
        };
      }
      {
        alert = "TempoIngesterReplayErrors";
        expr = ''sum(increase(tempo_ingester_replay_errors_total[5m])) > 0'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          summary = "Tempo ingester has encountered errors while replaying a block on startup for tenant {{ $labels.tenant }} on {{ $labels.nomad_alloc_name }}";
          runbook_url = "https://github.com/grafana/tempo/tree/main/operations/tempo-mixin/runbook.md#TempoIngesterReplayErrors";
        };
      }
    ];
  };
}
