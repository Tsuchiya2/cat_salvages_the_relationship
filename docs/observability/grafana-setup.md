# Grafana Dashboard Setup Guide

This guide explains how to set up and use the MySQL 8 Migration Dashboard in Grafana.

## Prerequisites

- Grafana 8.0 or higher
- Prometheus data source configured in Grafana
- Rails application exposing metrics at `/metrics` endpoint

## Dashboard Import

### Option 1: Import from File

1. Open Grafana web interface
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select `config/grafana/mysql8-migration-dashboard.json`
5. Select your Prometheus data source
6. Click **Import**

### Option 2: Import from JSON

1. Open Grafana web interface
2. Navigate to **Dashboards** → **Import**
3. Paste the contents of `config/grafana/mysql8-migration-dashboard.json`
4. Select your Prometheus data source
5. Click **Import**

## Dashboard Panels

The MySQL 8 Migration Dashboard includes 4 panels:

### 1. Database Connection Pool

**Metrics Displayed:**
- Pool Size (Total) - Total number of connections in the pool
- Available Connections - Connections ready to use
- In Use Connections - Connections currently active
- Waiting Threads - Threads waiting for a connection

**PromQL Queries:**
```promql
database_pool_size
database_pool_available
database_pool_size - database_pool_available
database_pool_waiting
```

**Interpretation:**
- If "In Use Connections" approaches "Pool Size", consider increasing pool size
- If "Waiting Threads" is consistently > 0, connections are exhausted
- Normal: Available connections should be > 0 most of the time

### 2. Query Performance (95th & 99th Percentile)

**Metrics Displayed:**
- 95th percentile query duration by operation type (SELECT, INSERT, UPDATE, DELETE)
- 99th percentile query duration by operation type

**PromQL Queries:**
```promql
# 95th percentile
histogram_quantile(0.95, sum(rate(database_query_duration_seconds_bucket[5m])) by (le, operation))

# 99th percentile
histogram_quantile(0.99, sum(rate(database_query_duration_seconds_bucket[5m])) by (le, operation))
```

**Interpretation:**
- Queries > 200ms at 95th percentile should be investigated
- Queries > 1s at 99th percentile indicate performance issues
- Compare operation types to identify which queries are slow

**Threshold Colors:**
- Green: < 100ms
- Yellow: 100-200ms
- Red: > 200ms

### 3. Migration Progress

**Metrics Displayed:**
- Migration completion percentage (0-100%)

**PromQL Query:**
```promql
migration_progress_percent
```

**Interpretation:**
- Shows real-time progress of database migration
- Gauge visualization with color-coded thresholds:
  - Red: 0-25%
  - Yellow: 25-50%
  - Green: 50-100%
  - Blue: 100% (complete)

### 4. Migration Errors

**Metrics Displayed:**
- Error rate by error type (connection, timeout, data, unknown)

**PromQL Query:**
```promql
rate(migration_errors_total[5m])
```

**Interpretation:**
- Any errors during migration should be investigated immediately
- Error types help identify root cause:
  - `connection`: Database connectivity issues
  - `timeout`: Query timeouts or slow operations
  - `data`: Data integrity or constraint violations
  - `unknown`: Unexpected errors

## Prometheus Configuration

### Scrape Configuration

Add this to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'rails_cat_salvages'
    scrape_interval: 10s
    scrape_timeout: 5s
    metrics_path: '/metrics'
    static_configs:
      - targets: ['localhost:3000']  # Adjust host:port as needed
    basic_auth:
      username: 'monitor_username'
      password: 'monitor_password'
```

### Environment Variables

Set these environment variables for authentication:

```bash
export MONITOR_USERNAME='your_username'
export MONITOR_PASSWORD='your_secure_password'
```

## Dashboard Settings

### Refresh Rate

The dashboard auto-refreshes every 10 seconds. To change this:

1. Click the **Refresh** dropdown in the top-right
2. Select desired interval (5s, 10s, 30s, 1m, etc.)
3. Click **Save dashboard**

### Time Range

Default time range is **Last 1 hour**. To change:

1. Click the **time range selector** in the top-right
2. Select desired range (Last 5m, 15m, 1h, 6h, 24h, etc.)
3. Or use **Custom range** for specific dates

### Variables (Optional)

To add environment filtering:

1. Click **Dashboard settings** (gear icon)
2. Go to **Variables** tab
3. Add a new variable:
   - Name: `environment`
   - Type: Query
   - Data source: Prometheus
   - Query: `label_values(environment)`
4. Use `{environment="$environment"}` in queries

## Alerting Integration

The dashboard integrates with alert rules defined in `config/alerting_rules.yml`.

To view active alerts:
1. Click the **bell icon** in the top menu
2. View **Active alerts**
3. Click an alert for details

## Troubleshooting

### No Data in Panels

**Possible causes:**
1. Prometheus not scraping metrics endpoint
   - Check Prometheus targets: `http://prometheus:9090/targets`
   - Verify authentication credentials
2. Rails application not running
   - Start Rails server: `rails server`
3. Metrics not initialized
   - Access `/metrics` endpoint to initialize metrics

### Incorrect Values

**Possible causes:**
1. Metrics not updating
   - Check `lib/database_metrics.rb` is loaded
   - Verify background thread is running
2. Query errors
   - Check Prometheus logs for scrape errors
   - Verify PromQL query syntax

### Dashboard Not Importing

**Possible causes:**
1. Incompatible Grafana version
   - Requires Grafana 8.0+
   - Update Grafana if needed
2. Invalid JSON
   - Validate JSON at jsonlint.com
   - Check for syntax errors

## Best Practices

### Monitoring During Migration

1. **Before migration:**
   - Set up dashboard and alerts
   - Test with sample data
   - Verify all panels showing data

2. **During migration:**
   - Monitor dashboard continuously
   - Watch for connection pool exhaustion
   - Check error panel for issues
   - Track progress percentage

3. **After migration:**
   - Compare query performance before/after
   - Verify no lingering errors
   - Adjust pool size if needed

### Alert Response

When alerts fire:

1. **HighDatabaseConnectionPoolUsage**
   - Check "In Use Connections" panel
   - Increase pool size in `database.yml`
   - Restart application

2. **SlowDatabaseQueries**
   - Check "Query Performance" panel
   - Identify slow operation type
   - Review and optimize queries
   - Add database indexes if needed

3. **MigrationErrors**
   - Check application logs: `log/migration.log`
   - Identify error type from panel
   - Fix root cause
   - Resume migration

4. **DatabaseConnectionFailure**
   - Check database server status
   - Verify network connectivity
   - Check database credentials
   - Review database logs

## Maintenance

### Regular Tasks

1. **Weekly:**
   - Review query performance trends
   - Check for degradation
   - Optimize slow queries

2. **Monthly:**
   - Export dashboard JSON for backup
   - Update dashboard based on new requirements
   - Review and adjust alert thresholds

3. **After migrations:**
   - Archive dashboard snapshot
   - Document any issues encountered
   - Update runbook if needed

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Rails Metrics Best Practices](../api/health-endpoints.md)
- [Alerting Rules Configuration](alerting.md)
