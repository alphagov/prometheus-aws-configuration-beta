- job_name: dcs-federate
  scheme: https
  honor_labels: true
  honor_timestamps: true
  metrics_path: '/federate'
  params:
    "match[]":
    # fetch everything (via https://stackoverflow.com/a/39253848 )
    - '{__name__=~".+"}'
  static_configs:
  - targets:
    - dcs-build-internal-prometheus.london.cloudapps.digital
    labels:
      federated_from: dcs-build-internal-prometheus.london.cloudapps.digital
  - targets:
    - dcs-integration-internal-prometheus.london.cloudapps.digital
    labels:
      federated_from: dcs-integration-internal-prometheus.london.cloudapps.digital
  - targets:
    - dcs-production-internal-prometheus.london.cloudapps.digital
    labels:
      federated_from: dcs-production-internal-prometheus.london.cloudapps.digital


- job_name: paas_elasticsearch_for_dm
  scheme: https
  basic_auth:
    username: digitalmarketplace
    password: ${dm_elasticsearch_metrics_password}
  metrics_path: '/federate'
  params:
    "match[]":
    - "{job='aiven'}"
  static_configs:
  - targets:
    - digitalmarketplace-es-metrics.cloudapps.digital
  metric_relabel_configs:
  # Prepend `paas_es_` so the metrics are easier to find
  - action: replace
    source_labels: [__name__]
    target_label: __name__
    regex: (.*)
    replacement: paas_es_$${1}
  # Dummy entry to be used below
  - &store_this_metric
    action: replace
    target_label: __store_this__
    replacement: store_this
    source_labels: [__name__]
    regex: __dummy_metric_name
  # One entry for each metric you want to import into Prometheus.
  # (Or remove this and the drop rules below it in order to import all
  # nearly 1000 metrics.)
  - <<: *store_this_metric
    regex: paas_es_disk_free
  - <<: *store_this_metric
    regex: paas_es_disk_used_percent
  - <<: *store_this_metric
    regex: paas_es_diskio_io_time
  - <<: *store_this_metric
    regex: paas_es_diskio_iops_in_progress
  - <<: *store_this_metric
    regex: paas_es_diskio_read_time
  - <<: *store_this_metric
    regex: paas_es_diskio_write_time
  - <<: *store_this_metric
    regex: paas_es_swap_used_percent
  - <<: *store_this_metric
    regex: paas_es_system_load1
  - <<: *store_this_metric
    regex: paas_es_system_load5
  - <<: *store_this_metric
    regex: paas_es_system_load15
  - <<: *store_this_metric
    regex: paas_es_net_bytes_recv
  - <<: *store_this_metric
    regex: paas_es_net_bytes_sent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_os_mem_free_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_os_mem_used_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_process_cpu_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_indices_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_indices_docs_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_indices_docs_deleted
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_indices_query_cache_miss_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_indices_store_size_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_count_master
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_count_total
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_fs_available_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_fs_free_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_fs_total_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_jvm_mem_heap_max_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_jvm_mem_heap_used_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_jvm_threads
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_process_open_file_descriptors_avg
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_process_open_file_descriptors_max
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_clusterstats_nodes_process_open_file_descriptors_min
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_active_primary_shards
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_active_shards
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_active_shards_percent_as_number
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_initializing_shards
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_number_of_data_nodes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_number_of_nodes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_number_of_pending_tasks
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_relocating_shards
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_status_code
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_task_max_waiting_in_queue_millis
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_cluster_health_unassigned_shards
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_indices_docs_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_indices_docs_deleted
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_indices_request_cache_hit_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_indices_request_cache_miss_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_cpu_load_average_15m
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_cpu_load_average_1m
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_cpu_load_average_5m
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_cpu_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_mem_free_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_mem_used_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_swap_total_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_os_swap_used_in_bytes
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_process_max_file_descriptors
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_process_open_file_descriptors
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_jvm_gc_collectors_old_collection_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_jvm_gc_collectors_old_collection_time_in_millis
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_jvm_gc_collectors_young_collection_count
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_jvm_gc_collectors_young_collection_time_in_millis
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_jvm_mem_heap_used_percent
  - <<: *store_this_metric
    regex: paas_es_elasticsearch_jvm_uptime_in_millis
  # Drop metrics we don't want to keep
  - source_labels: [__store_this__]
    regex: ^store_this$
    action: keep
  # Drop the temporary label
  - regex: ^__store_this__$
    action: labeldrop
- job_name: paas_redis_metrics_for_dm
  scheme: https
  basic_auth:
    username: ${dm_paas_metrics_username}
    password: ${dm_paas_metrics_password}
  static_configs:
  - targets:
    - redis.metrics.cloud.service.gov.uk
  metrics_path: /metrics
  scrape_interval: 300s
  scrape_timeout: 120s
  honor_timestamps: true
  metric_relabel_configs:
  # Prepend `paas_redis_` so the metrics are easier to find
  - action: replace
    source_labels: [__name__]
    target_label: __name__
    regex: (.*)
    replacement: paas_redis_$${1}
