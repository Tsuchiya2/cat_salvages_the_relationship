# Alerting Configuration Guide

This guide explains the alerting rules configured for MySQL 8 database migration monitoring.

## Overview

The alerting system monitors database performance, connection pool usage, and migration progress. Alerts are defined in `config/alerting_rules.yml` and evaluated by Prometheus.

## Alert Severity Levels

- **Critical** - Immediate action required, service degradation or outage
- **Warning** - Attention needed, potential issues developing

## Alert Rules

### 1. HighDatabaseConnectionPoolUsage

**Severity:** Warning
**Threshold:** > 80% pool utilization for 2 minutes
**Category:** Performance

**Description:**
Triggers when the database connection pool is running low on available connections.

**PromQL Expression:**
```promql
(database_pool_size - database_pool_available) / database_pool_size * 100 > 80
```

**Impact:**
- Application may start queueing database requests
- Response times will increase
- Risk of connection pool exhaustion

**Response Actions:**

1. **Immediate (< 5 minutes):**
   - Check Grafana dashboard for current pool state
   - Review active connections: `SELECT * FROM information_schema.processlist;`
   - Identify long-running queries

2. **Short-term (< 30 minutes):**
   - Kill non-critical long-running queries
   - Review application logs for connection leaks
   - Monitor if situation resolves

3. **Long-term (< 24 hours):**
   - Increase pool size in `config/database.yml`
   - Optimize slow queries holding connections
   - Review connection timeout settings
   - Fix any connection leak bugs

**Example Investigation:**
```bash
# Check pool stats via Rails console
rails console
> DatabaseMetrics.pool_stats

# Review slow queries
tail -f log/production.log | grep "duration="

# Check for leaked connections
lsof -i :3306 | wc -l
```

---

### 2. SlowDatabaseQueries

**Severity:** Warning
**Threshold:** 95th percentile > 200ms for 5 minutes
**Category:** Performance

**Description:**
Triggers when database queries are consistently slow at the 95th percentile.

**PromQL Expression:**
```promql
histogram_quantile(0.95,
  sum(rate(database_query_duration_seconds_bucket[5m])) by (le, operation)
) > 0.2
```

**Impact:**
- Increased page load times
- Poor user experience
- Risk of request timeouts

**Response Actions:**

1. **Immediate (< 5 minutes):**
   - Check Grafana to identify which operation type (SELECT/INSERT/UPDATE/DELETE) is slow
   - Review recent code deployments
   - Check database server load

2. **Short-term (< 30 minutes):**
   - Enable slow query log: `SET GLOBAL slow_query_log = 1;`
   - Review `log/production.log` for slow queries
   - Run EXPLAIN on identified slow queries
   - Check for missing indexes

3. **Long-term (< 24 hours):**
   - Add database indexes for slow queries
   - Optimize query logic (avoid N+1, use includes)
   - Consider query caching
   - Review database statistics: `ANALYZE TABLE table_name;`

**Example Investigation:**
```sql
-- Find slow queries
SELECT * FROM mysql.slow_log
ORDER BY query_time DESC
LIMIT 10;

-- Analyze query performance
EXPLAIN ANALYZE SELECT ...;

-- Check index usage
SHOW INDEX FROM table_name;
```

---

### 3. MigrationErrors

**Severity:** Critical
**Threshold:** Any errors in 5 minutes
**Category:** Reliability

**Description:**
Triggers when database migration encounters errors.

**PromQL Expression:**
```promql
increase(migration_errors_total[5m]) > 0
```

**Impact:**
- Migration may fail or produce incorrect results
- Data integrity at risk
- Migration rollback may be required

**Response Actions:**

1. **Immediate (< 2 minutes):**
   - Check migration logs: `tail -f log/migration.log`
   - Identify error type (connection, timeout, data, unknown)
   - Assess severity and data impact

2. **Short-term (< 10 minutes):**
   - If critical errors: **PAUSE MIGRATION**
   - Review error stack traces
   - Check database constraints and triggers
   - Verify data integrity

3. **Long-term (< 1 hour):**
   - Fix root cause (constraints, data format, etc.)
   - Test fix on sample data
   - Resume migration with monitoring
   - Document issue in runbook

**Error Types:**

- **connection** - Database connectivity issues
  - Check network, credentials, firewall
  - Verify database server is running

- **timeout** - Query timeouts
  - Check slow queries
  - Increase timeout if appropriate
  - Optimize query performance

- **data** - Data integrity violations
  - Check constraint violations
  - Review data format issues
  - Fix data before retry

- **unknown** - Unexpected errors
  - Review full stack trace
  - Check application logs
  - May require code fix

**Example Investigation:**
```bash
# Review migration logs
tail -100 log/migration.log | jq 'select(.event == "migration_error")'

# Check for constraint violations
mysql -e "SELECT * FROM information_schema.table_constraints WHERE constraint_schema = 'your_database';"

# Verify data integrity
rails runner "User.where('email IS NULL OR email = ""').count"
```

---

### 4. DatabaseConnectionFailure

**Severity:** Critical
**Threshold:** Down for 1 minute
**Category:** Availability

**Description:**
Triggers when the application cannot connect to the database.

**PromQL Expression:**
```promql
up{job="rails_cat_salvages"} == 0
```

**Impact:**
- **Application is DOWN**
- All requests will fail
- Users cannot access the service

**Response Actions:**

1. **Immediate (< 1 minute):**
   - Check database server status
   - Verify network connectivity
   - Check application server status

2. **Short-term (< 5 minutes):**
   - Restart database if down
   - Check database logs for errors
   - Verify credentials and connection string
   - Check firewall rules

3. **Long-term (< 30 minutes):**
   - Investigate root cause
   - Check for resource exhaustion
   - Review monitoring for patterns
   - Update runbook with findings

**Example Investigation:**
```bash
# Test database connectivity
mysql -h localhost -u user -p -e "SELECT 1;"

# Check database server status
systemctl status mysql

# Check network connectivity
telnet localhost 3306

# Review database logs
tail -100 /var/log/mysql/error.log

# Check resource usage
top
df -h
```

---

### 5. DatabaseConnectionPoolExhausted

**Severity:** Critical
**Threshold:** 0 available connections with waiting threads for 30 seconds
**Category:** Performance

**Description:**
Triggers when all database connections are in use and requests are queuing.

**PromQL Expression:**
```promql
database_pool_available == 0 and database_pool_waiting > 0
```

**Impact:**
- Requests are queuing and may timeout
- Severe application performance degradation
- Users experiencing errors

**Response Actions:**

1. **Immediate (< 1 minute):**
   - Check for connection leaks
   - Review active connections
   - Consider emergency restart

2. **Short-term (< 10 minutes):**
   - Kill long-running queries if safe
   - Temporarily increase pool size
   - Monitor recovery

3. **Long-term (< 1 hour):**
   - Fix connection leak bugs
   - Optimize query performance
   - Right-size connection pool
   - Add circuit breaker if needed

**Example Investigation:**
```ruby
# Rails console
rails console

# Check pool stats
DatabaseMetrics.pool_stats

# List active connections
ActiveRecord::Base.connection_pool.connections.each do |conn|
  puts "In use: #{conn.in_use?}, Owner: #{conn.owner}"
end

# Force disconnect idle connections (use with caution)
ActiveRecord::Base.connection_pool.disconnect!
```

---

### 6. MigrationStalled

**Severity:** Warning
**Threshold:** No progress for 10 minutes
**Category:** Reliability

**Description:**
Triggers when migration progress has not changed for 10 minutes.

**PromQL Expression:**
```promql
changes(migration_progress_percent[10m]) == 0
and migration_progress_percent > 0
and migration_progress_percent < 100
```

**Impact:**
- Migration may be stuck
- Completion delayed
- May require manual intervention

**Response Actions:**

1. **Immediate (< 5 minutes):**
   - Check if migration process is still running
   - Review application logs
   - Check system resources

2. **Short-term (< 15 minutes):**
   - Check for database locks
   - Review slow queries
   - Monitor I/O and CPU

3. **Long-term (< 1 hour):**
   - Identify bottleneck
   - Consider chunking large operations
   - May need to restart migration

**Example Investigation:**
```sql
-- Check for blocking locks
SELECT * FROM information_schema.innodb_locks;

-- Check for long-running transactions
SELECT * FROM information_schema.innodb_trx
WHERE trx_started < NOW() - INTERVAL 5 MINUTE;

-- Check processlist
SHOW PROCESSLIST;
```

---

## Prometheus Configuration

### Loading Alert Rules

Add to your `prometheus.yml`:

```yaml
rule_files:
  - '/path/to/config/alerting_rules.yml'
```

### Alertmanager Configuration

Configure alert routing in `alertmanager.yml`:

```yaml
route:
  receiver: 'team-database'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    # Critical alerts
    - match:
        severity: critical
      receiver: 'pagerduty'
      continue: true

    # Warning alerts
    - match:
        severity: warning
      receiver: 'slack-warnings'

receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'your-pagerduty-key'

  - name: 'slack-warnings'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#database-alerts'
```

## Testing Alerts

### Manual Alert Testing

```bash
# Trigger HighDatabaseConnectionPoolUsage (use test environment!)
rails runner "
  pool = ActiveRecord::Base.connection_pool
  (pool.size * 0.9).to_i.times do
    Thread.new { ActiveRecord::Base.connection.execute('SELECT SLEEP(60)') }
  end
  sleep 120
"

# Trigger SlowDatabaseQueries
rails runner "
  100.times do
    ActiveRecord::Base.connection.execute('SELECT SLEEP(0.3)')
  end
"

# Trigger MigrationErrors
DatabaseMigration::Logger.log_migration_error(
  error: StandardError.new('Test error'),
  context: { test: true }
)
```

### Verify Alert Rules

```bash
# Validate alert rules syntax
promtool check rules config/alerting_rules.yml

# Test alert expression
curl 'http://prometheus:9090/api/v1/query?query=database_pool_available'
```

## Alert Maintenance

### Regular Tasks

1. **Weekly:**
   - Review fired alerts
   - Tune thresholds if needed
   - Update runbooks

2. **Monthly:**
   - Review alert effectiveness
   - Add new alerts for new features
   - Remove obsolete alerts

3. **After incidents:**
   - Document response in runbook
   - Adjust thresholds if false positives
   - Add new alerts if gaps identified

## Silencing Alerts

### Temporary Silences

During planned maintenance:

```bash
# Create silence via amtool
amtool silence add \
  alertname="HighDatabaseConnectionPoolUsage" \
  --duration=2h \
  --comment="Planned migration, expect high pool usage"
```

## Additional Resources

- [Prometheus Alerting Documentation](https://prometheus.io/docs/alerting/latest/)
- [Grafana Dashboard Setup](grafana-setup.md)
- [Health Check Endpoints](../api/health-endpoints.md)
