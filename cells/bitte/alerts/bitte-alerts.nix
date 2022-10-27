{...}: {
  bitte-consul = {
    datasource = "vm";
    rules = [
      {
        alert = "ConsulACLResolvesAlert";
        expr = "avg_over_time(consul_acl_ResolveToken_count[5m]) > 3000";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Average ACL resolves on {{ $labels.host }} over the past 5 minutes is > 3000.
             A consul servers (or client) may be overloaded or not functioning correctly.'';
          summary = "[Consul] ACL Resolves alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulCatalogDeregistrationAlert";
        expr = ''avg_over_time(consul_catalog_deregister_count)[1h] > 10'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Average catalog deregistration operations on {{ $labels.host }} over the past 1 hour is > 10.
             The consul servers may be overloaded or not functioning correctly.'';
          summary = "[Consul] Catalog Deregistration alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulCatalogRegistrationAlert";
        expr = ''avg_over_time(consul_catalog_register_count)[1h] > 10'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Average catalog registration operations on {{ $labels.host }} over the past 1 hour is > 10.
             The consul servers may be overloaded or not functioning correctly.'';
          summary = "[Consul] Catalog Registration alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulCoreNodeMemoryUtilization";
        expr = ''mem_used_percent{host=~"core.*"} > 50'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Core node {{ $labels.host }} has memory utilization above 50% for the past 5 minutes.
             If memory utilization rises further and OOM takes place, consul, vault and nomad stability may be at risk.'';
          summary = "[Consul] Core Node Memory Utilization alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulKVsApplyAlert";
        expr = "avg_over_time(consul_kvs_apply_count[1h]) > 20";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Average key-value store commit time on {{ $labels.host }} over the past hour is > 20 ms.
             The consul servers may be overloaded or not functioning correctly.'';
          summary = "[Consul] KVs apply alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulLastLeaderContactAlert";
        expr = "consul_raft_leader_lastContact_count > 200";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Leadership contact latency is exceedingly high (> 200 ms) for host {{ $labels.host }}. The consul cluster may be degraded.";
          summary = "[Consul] Raft Leader Last Contact alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulRaftApplyAlert";
        expr = "avg_over_time(consul_raft_apply_value[1h]) > 20";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Average raft apply time on {{ $labels.host }} over the past hour is > 20 ms. The consul servers may be overloaded or not functioning correctly.";
          summary = "[Consul] Raft Apply alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulRaftCommitTimeAlert";
        expr = "avg_over_time(consul_raft_commitTime_count[1h]) > 20";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Average raft commit time over the past hour on {{ $labels.host }} is > 20 ms. The consul servers may be overloaded or not functioning correctly.";
          summary = "[Consul] Raft Commit Time alert on {{ $labels.host }}";
        };
      }
      {
        alert = "ConsulRaftElectionAlert";
        expr = "sum(changes((union(consul_raft_state_candidate_value,0))[1h])) > 1";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "There has been more than one raft election change in the past hour. Leadership may be flapping.";
          summary = "[Consul] Raft Elections alert";
        };
      }
      {
        alert = "ConsulRaftLeaderAlert";
        expr = "sum(changes(union(consul_raft_state_leader_value, 0)[1h])) > 1";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "There has been more than one raft leader change in the past hour. Leadership may be flapping.";
          summary = "[Consul] Raft Leader alert";
        };
      }
    ];
  };

  bitte-loki = {
    datasource = "loki";
    rules = [
      {
        alert = "CoredumpDetected";
        expr = ''sum(rate({syslog_identifier="systemd-coredump"}[1h] != "sshd" |= "dumped core")) by (host) > 0'';
        for = "1m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Detected a coredump on {{ $labels.host }}.
             This usually requires attention and most likely manual intervention.
             To analyze a coredump, run `coredumpctl list` on the affected machine, and run `coredump debug $id` in a nix shell with gdb.'';
          summary = "Detected a coredump on {{ $labels.host }}";
        };
      }
    ];
  };

  bitte-system = {
    datasource = "vm";
    rules = [
      {
        alert = "SystemCpuUsedAlert";
        expr = ''100 - cpu_usage_idle{cpu="cpu-total",host!~"ip-.*"} > 90'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "CPU has been above 90% on {{ $labels.host }} for more than 5 minutes.";
          summary = "[System] CPU Used alert on {{ $labels.host }}";
        };
      }
      {
        alert = "SystemDiskUsedSlashAlert";
        expr = ''disk_used_percent{path="/"} > 80'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Disk used on {{ $labels.host }} on mount / has been above 80% for more than 5 minutes.";
          summary = "[System] Disk used / alert on {{ $labels.host }}";
        };
      }
      {
        alert = "SystemDiskUsedSlashPredictedAlert";
        expr = ''predict_linear(disk_used_percent{path="/"}[1h], 12 * 3600) > 90'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Linear extrapolation predicts disk usage on {{ $labels.host }} will be above 90% within 12 hours.";
          summary = "[System] Predicted Disk used / alert on {{ $labels.host }}";
        };
      }
      {
        alert = "SystemDiskUsedVarClientAlert";
        expr = ''disk_used_percent{host=~`^ip-.*$`,path="/var"} > 80'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Disk used on client {{ $labels.host }} /var has been above 80% for more than 5 minutes.";
          summary = "[System] Disk used Clients /var alert on {{ $labels.host }}";
        };
      }
      {
        alert = "SystemDiskUsedVarClientPredictedAlert";
        expr = ''predict_linear(disk_used_percent{host=~`^ip-.*$`,path="/var"}[12h], 12 * 3600) > 90'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Linear extrapolation predicts client disk usage on /var on {{ $labels.host }} will be above 90% within 12 hours.";
          summary = "[System] Predicted Disk used clients /var alert on {{ $labels.host }}";
        };
      }
      {
        alert = "SystemMemoryUsedAlert";
        expr = "mem_used_percent > 90";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Memory used has been above 90% for more than 5 minutes.";
          summary = "[System] Memory Used alert on {{ $labels.host }}";
        };
      }
    ];
  };

  bitte-vault = {
    datasource = "vm";
    rules = [
      {
        alert = "VaultCoreLeadershipLost";
        expr = "vault_core_leadership_lost_count > 0";
        for = "1m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Detected a lost vault leadership on {{ $labels.host }}.
             This should be monitored and alerted on for overall cluster leadership status.'';
          summary = "Detected a vault leadership loss on {{ $labels.host }}";
        };
      }
      {
        alert = "VaultLeaseExpirationRate";
        expr = ''rate(vault_expire_num_leases_value[1m]) * 60 > 25'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            More than 25 expired vault leases per minute have occured on {{ $labels.host }} for the past 5 minutes.
              This should be investigated to ensure vault is not stuck in a lease loop.'';
          summary = "High lease expiration rate on {{ $labels.host }} -- investigation needed";
        };
      }
      {
        alert = "VaultLeaseExpirationIncrease";
        expr = ''increase(vault_expire_num_leases_value[10m]) > 100'';
        for = "2m";
        labels.severity = "critical";
        annotations = {
          description = ''
            More than 100 expired vault leases have occurred on {{ $labels.host }} in the past 10 minutes.
              This should be investigated to ensure vault is not stuck in a lease loop.'';
          summary = "High lease expiration increase on {{ $labels.host }} -- investigation needed";
        };
      }
      {
        alert = "VaultTokenCountRate";
        expr = ''rate(vault_token_count_value[1m]) * 60 > 25'';
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            More than 25 new vault tokens per minute have been created on {{ $labels.host }} for the past 5 minutes.
              This should be investigated to ensure vault is not stuck in a token loop.'';
          summary = "High token creation rate on {{ $labels.host }} -- investigation needed";
        };
      }
      {
        alert = "VaultTokenCountIncrease";
        expr = ''increase(vault_token_count_value[10m]) > 100'';
        for = "2m";
        labels.severity = "critical";
        annotations = {
          description = ''
            More than 100 new vault tokens have been created on {{ $labels.host }} in the past 10 minutes.
             This should be investigated to ensure vault is not stuck in a token loop.'';
          summary = "High token increase on {{ $labels.host }} -- investigation needed";
        };
      }
    ];
  };

  bitte-vm-health = {
    datasource = "vm";
    rules = [
      {
        alert = "TooManyRestarts";
        expr = ''changes(process_start_time_seconds{job=~"victoriametrics|vmagent|vmalert"}[15m]) > 2'';
        labels.severity = "critical";
        annotations = {
          description = "Job {{ $labels.job }} has restarted more than twice in the last 15 minutes. It might be crashlooping.";
          summary = "{{ $labels.job }} too many restarts (instance {{ $labels.instance }})";
        };
      }
      {
        alert = "ServiceDown";
        expr = ''up{job=~"victoriametrics|vmagent|vmalert"} == 0'';
        for = "2m";
        labels.severity = "critical";
        annotations = {
          description = "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes.";
          summary = "Service {{ $labels.job }} is down on {{ $labels.instance }}";
        };
      }
      {
        alert = "ProcessNearFDLimits";
        expr = "(process_max_fds - process_open_fds) < 100";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = "Exhausting OS file descriptors limit can cause severe degradation of the process. Consider to increase the limit as fast as possible.";
          summary = ''
            Number of free file descriptors is less than 100 for "{{ $labels.job }}"("{{ $labels.instance }}") for the last 5m'';
        };
      }
      {
        alert = "TooHighMemoryUsage";
        expr = "(process_resident_memory_anon_bytes / vm_available_memory_bytes) > 0.9";
        for = "5m";
        labels.severity = "critical";
        annotations = {
          description = ''
            Too high memory usage may result into multiple issues such as OOMs or degraded performance.
             Consider to either increase available memory or decrease the load on the process.'';
          summary = ''
            It is more than 90% of memory used by "{{ $labels.job }}"("{{ $labels.instance }}") during the last 5m'';
        };
      }
    ];
  };

  bitte-vm-standalone = {
    datasource = "vm";
    rules = [
      {
        alert = "DiskRunsOutOfSpaceIn3Days";
        expr = ''
          vm_free_disk_space_bytes / ignoring(path)
          (
             (
              rate(vm_rows_added_to_storage_total[1d]) -
              ignoring(type) rate(vm_deduplicated_samples_total{type="merge"}[1d])
             )
            * scalar(
              sum(vm_data_size_bytes{type!="indexdb"}) /
              sum(vm_rows{type!="indexdb"})
             )
          ) < 3 * 24 * 3600
        '';
        for = "30m";
        labels.severity = "critical";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=73&var-instance={{ $labels.instance }}";
          description = ''
            Taking into account current ingestion rate, free disk space will be enough only for {{ $value | humanizeDuration }} on instance {{ $labels.instance }}.
             Consider to limit the ingestion rate, decrease retention or scale the disk space if possible.'';
          summary = "Instance {{ $labels.instance }} will run out of disk space soon";
        };
      }
      {
        alert = "DiskRunsOutOfSpace";
        expr = ''
          sum(vm_data_size_bytes) by(instance) /
          (
           sum(vm_free_disk_space_bytes) by(instance) +
           sum(vm_data_size_bytes) by(instance)
          ) > 0.8
        '';
        for = "30m";
        labels.severity = "critical";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=53&var-instance={{ $labels.instance }}";
          description = ''
            Disk utilisation on instance {{ $labels.instance }} is more than 80%.
             Having less than 20% of free disk space could cripple merges processes and overall performance.
             Consider to limit the ingestion rate, decrease retention or scale the disk space if possible.'';
          summary = "Instance {{ $labels.instance }} will run out of disk space soon";
        };
      }
      {
        alert = "RequestErrorsToAPI";
        expr = "increase(vm_http_request_errors_total[5m]) > 0";
        for = "30m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=35&var-instance={{ $labels.instance }}";
          description = ''
            Requests to path {{ $labels.path }} are receiving errors for more than 30m.
             Please verify if clients are sending correct requests.'';
          summary = "Too many errors served for path {{ $labels.path }} (instance {{ $labels.instance }})";
        };
      }
      {
        alert = "ConcurrentFlushesHitTheLimit";
        expr = "avg_over_time(vm_concurrent_addrows_current[1m]) >= vm_concurrent_addrows_capacity";
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=59&var-instance={{ $labels.instance }}";
          description = ''
            The limit of concurrent flushes on instance {{ $labels.instance }} is equal to number of CPUs.
             When VictoriaMetrics constantly hits the limit it means that storage is overloaded and requires more CPU.'';
          summary = "VictoriaMetrics on instance {{ $labels.instance }} is constantly hitting concurrent flushes limit";
        };
      }
      {
        alert = "TooManyLogs";
        expr = ''sum(increase(vm_log_messages_total{level!="info"}[5m])) by (job, instance) > 0'';
        for = "30m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=67&var-instance={{ $labels.instance }}";
          description = ''
            Logging rate for job "{{ $labels.job }}" ({{ $labels.instance }}) is {{ $value }} for last 30m.
             Worth to check logs for specific error messages.'';
          summary = ''
            Too many logs printed for job "{{ $labels.job }}" ({{ $labels.instance }})'';
        };
      }
      {
        alert = "RowsRejectedOnIngestion";
        expr = "sum(rate(vm_rows_ignored_total[5m])) by (instance, reason) > 0";
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=58&var-instance={{ $labels.instance }}";
          description = ''
            VM is rejecting to ingest rows on "{{ $labels.instance }}" due to the following reason: "{{ $labels.reason }}"'';
          summary = ''
            Some rows are rejected on "{{ $labels.instance }}" on ingestion attempt'';
        };
      }
      {
        alert = "TooHighChurnRate";
        expr = ''
          (
             sum(rate(vm_new_timeseries_created_total[5m])) by(instance)
             /
             sum(rate(vm_rows_inserted_total[5m])) by (instance)
           ) > 0.1
        '';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=66&var-instance={{ $labels.instance }}";
          description = ''
            VM constantly creates new time series on "{{ $labels.instance }}".
             This effect is known as Churn Rate.
             High Churn Rate tightly connected with database performance and may result in unexpected OOM's or slow queries.'';
          summary = ''
            Churn rate is more than 10% on "{{ $labels.instance }}" for the last 15m'';
        };
      }
      {
        alert = "TooHighChurnRate24h";
        expr = ''
          sum(increase(vm_new_timeseries_created_total[24h])) by(instance)
          >
          (sum(vm_cache_entries{type="storage/hour_metric_ids"}) by(instance) * 3)
        '';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=66&var-instance={{ $labels.instance }}";
          description = ''
            The number of created new time series over last 24h is 3x times higher than current number of active series on "{{ $labels.instance }}".
             This effect is known as Churn Rate.
             High Churn Rate tightly connected with database performance and may result in unexpected OOM's or slow queries.'';
          summary = ''
            Too high number of new series on "{{ $labels.instance }}" created over last 24h'';
        };
      }
      {
        alert = "TooHighSlowInsertsRate";
        expr = ''
          (
             sum(rate(vm_slow_row_inserts_total[5m])) by(instance)
             /
             sum(rate(vm_rows_inserted_total[5m])) by (instance)
           ) > 0.5
        '';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/wNf0q_kZk?viewPanel=68&var-instance={{ $labels.instance }}";
          description = ''
            High rate of slow inserts on "{{ $labels.instance }}" may be a sign of resource exhaustion for the current load.
             It is likely more RAM is needed for optimal handling of the current number of active time series.'';
          summary = ''
            Percentage of slow inserts is more than 50% on "{{ $labels.instance }}" for the last 15m'';
        };
      }
      {
        alert = "LabelsLimitExceededOnIngestion";
        expr = "sum(increase(vm_metrics_with_dropped_labels_total[5m])) by (instance) > 0";
        for = "15m";
        labels = {severity = "warning";};
        annotations = {
          description = ''
            VictoriaMetrics limits the number of labels per each metric with `-maxLabelsPerTimeseries` command-line flag.
             This prevents from ingesting metrics with too many labels.
             Please verify that `-maxLabelsPerTimeseries` is configured correctly or that clients which send these metrics aren't misbehaving.'';
          summary = "Metrics ingested in ({{ $labels.instance }}) are exceeding labels limit";
        };
      }
    ];
  };

  bitte-vmagent = {
    datasource = "vm";
    rules = [
      {
        alert = "PersistentQueueIsDroppingData";
        expr = "sum(increase(vm_persistentqueue_bytes_dropped_total[5m])) by (job, instance) > 0";
        for = "10m";
        labels.severity = "critical";
        annotations = {
          dashboard = "{{ $externalURL }}/d/G7Z9GzMGz?viewPanel=49&var-instance={{ $labels.instance }}";
          description = "Vmagent dropped {{ $value | humanize1024 }} from persistent queue on instance {{ $labels.instance }} for the last 10m.";
          summary = "Instance {{ $labels.instance }} is dropping data from persistent queue";
        };
      }
      {
        alert = "TooManyScrapeErrors";
        expr = "sum(increase(vm_promscrape_scrapes_failed_total[5m])) by (job, instance) > 0";
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/G7Z9GzMGz?viewPanel=31&var-instance={{ $labels.instance }}";
          summary = ''
            Job "{{ $labels.job }}" on instance {{ $labels.instance }} fails to scrape targets for last 15m'';
        };
      }
      {
        alert = "TooManyWriteErrors";
        expr = ''
          (sum(increase(vm_ingestserver_request_errors_total[5m])) by (job, instance)
          +
          sum(increase(vmagent_http_request_errors_total[5m])) by (job, instance)) > 0
        '';
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/G7Z9GzMGz?viewPanel=77&var-instance={{ $labels.instance }}";
          summary = ''
            Job "{{ $labels.job }}" on instance {{ $labels.instance }} responds with errors to write requests for last 15m.'';
        };
      }
      {
        alert = "TooManyRemoteWriteErrors";
        expr = "sum(rate(vmagent_remotewrite_retries_count_total[5m])) by(job, instance, url) > 0";
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/G7Z9GzMGz?viewPanel=61&var-instance={{ $labels.instance }}";
          description = ''
            Vmagent fails to push data via remote write protocol to destination "{{ $labels.url }}"
             Ensure that destination is up and reachable.'';
          summary = ''
            Job "{{ $labels.job }}" on instance {{ $labels.instance }} fails to push to remote storage'';
        };
      }
      {
        alert = "RemoteWriteConnectionIsSaturated";
        expr = "rate(vmagent_remotewrite_send_duration_seconds_total[5m]) > 0.9";
        for = "15m";
        labels.severity = "warning";
        annotations = {
          dashboard = "{{ $externalURL }}/d/G7Z9GzMGz?viewPanel=84&var-instance={{ $labels.instance }}";
          description = ''
            The remote write connection between vmagent "{{ $labels.job }}" (instance {{ $labels.instance }}) and destination "{{ $labels.url }}" is saturated by more than 90% and vmagent won't be able to keep up.
             This usually means that `-remoteWrite.queues` command-line flag must be increased in order to increase the number of connections per each remote storage.'';
          summary = ''
            Remote write connection from "{{ $labels.job }}" (instance {{ $labels.instance }}) to {{ $labels.url }} is saturated'';
        };
      }
      {
        alert = "SeriesLimitHourReached";
        expr = "(vmagent_hourly_series_limit_current_series / vmagent_hourly_series_limit_max_series) > 0.9";
        labels.severity = "critical";
        annotations = {
          description = ''
            Max series limit set via -remoteWrite.maxHourlySeries flag is close to reaching the max value.
             Then samples for new time series will be dropped instead of sending them to remote storage systems.'';
          summary = "Instance {{ $labels.instance }} reached 90% of the limit";
        };
      }
      {
        alert = "SeriesLimitDayReached";
        expr = "(vmagent_daily_series_limit_current_series / vmagent_daily_series_limit_max_series) > 0.9";
        labels.severity = "critical";
        annotations = {
          description = ''
            Max series limit set via -remoteWrite.maxDailySeries flag is close to reaching the max value.
             Then samples for new time series will be dropped instead of sending them to remote storage systems.'';
          summary = "Instance {{ $labels.instance }} reached 90% of the limit";
        };
      }
    ];
  };
}
