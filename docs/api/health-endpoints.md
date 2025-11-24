# Health Check Endpoints API Documentation

This document describes the health check endpoints available for monitoring application and migration status.

## Overview

The application provides three health check endpoints:

1. **GET /health** - Shallow health check (fast, basic status)
2. **GET /health/deep** - Deep health check (comprehensive, all dependencies)
3. **GET /health/migration** - Migration-specific health check

All endpoints return JSON responses and use standard HTTP status codes to indicate health status.

## Authentication

In production environment, the `/health/deep` and `/health/migration` endpoints require HTTP Basic Authentication.

**Authentication Method:** HTTP Basic Auth

**Credentials:**
- Username: Set via `MONITOR_USERNAME` environment variable
- Password: Set via `MONITOR_PASSWORD` environment variable

**Example:**
```bash
curl -u username:password https://example.com/health/deep
```

The `/health` endpoint is unauthenticated and safe for load balancer health checks.

---

## Endpoint Details

### 1. GET /health

Shallow health check endpoint for load balancers and quick status verification.

**Purpose:** Fast, lightweight check suitable for load balancer health checks.

**Authentication:** None required

**Response Time:** < 10ms (typically 1-2ms)

**Success Response (200 OK):**
```json
{
  "status": "ok",
  "version": "2.0.0",
  "timestamp": "2025-11-24T10:30:00Z"
}
```

**Fields:**
- `status` (string): Always "ok" if endpoint responds
- `version` (string): Application version
- `timestamp` (string): ISO8601 timestamp

**Use Cases:**
- Load balancer health checks
- Quick availability verification
- Uptime monitoring

**Example:**
```bash
curl http://localhost:3000/health
```

---

### 2. GET /health/deep

Comprehensive health check that verifies all application dependencies.

**Purpose:** Thorough health verification including database and external services.

**Authentication:** Required in production

**Response Time:** 50-500ms (depends on database latency)

**Health Checks Performed:**
1. Database connectivity and latency
2. LINE API credentials validation

**Success Response (200 OK):**
```json
{
  "status": "healthy",
  "checks": {
    "database": {
      "status": "healthy",
      "latency_ms": 5.23
    },
    "line_credentials": {
      "status": "healthy"
    }
  },
  "timestamp": "2025-11-24T10:30:00Z"
}
```

**Error Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "checks": {
    "database": {
      "status": "unhealthy",
      "error": "Connection refused to database"
    },
    "line_credentials": {
      "status": "healthy"
    }
  },
  "timestamp": "2025-11-24T10:30:00Z"
}
```

**Fields:**
- `status` (string): Overall health status ("healthy" or "unhealthy")
- `checks` (object): Individual check results
  - `database` (object):
    - `status` (string): "healthy" or "unhealthy"
    - `latency_ms` (float): Database query latency in milliseconds
    - `error` (string, optional): Error message if unhealthy
  - `line_credentials` (object):
    - `status` (string): "healthy" or "unhealthy"
    - `error` (string, optional): Error message if unhealthy
- `timestamp` (string): ISO8601 timestamp

**Status Codes:**
- `200 OK` - All checks passed
- `503 Service Unavailable` - One or more checks failed
- `401 Unauthorized` - Authentication required (production only)
- `403 Forbidden` - Invalid credentials or missing environment variables

**Use Cases:**
- Pre-deployment health verification
- Monitoring system comprehensive checks
- Debugging connection issues
- Smoke testing after deployment

**Example:**
```bash
# Development
curl http://localhost:3000/health/deep

# Production
curl -u monitor:secret https://example.com/health/deep
```

---

### 3. GET /health/migration

Migration-specific health check for monitoring database migration progress and status.

**Purpose:** Track migration progress and verify database health during migrations.

**Authentication:** Required in production

**Response Time:** 50-200ms (depends on database)

**Health Checks Performed:**
1. Database reachability
2. Migration status (pending/in progress/complete)
3. Sample query execution

**Success Response (200 OK) - Migrations Complete:**
```json
{
  "status": "healthy",
  "checks": {
    "database_reachable": {
      "status": "healthy",
      "latency_ms": 5.23
    },
    "migrations_current": {
      "status": "healthy",
      "pending_migrations": 0
    },
    "sample_query_works": {
      "status": "healthy",
      "query_time_ms": 2.45
    }
  },
  "migration_in_progress": false,
  "timestamp": "2025-11-24T10:30:00Z"
}
```

**Migration In Progress Response (206 Partial Content):**
```json
{
  "status": "migration_in_progress",
  "checks": {
    "database_reachable": {
      "status": "healthy",
      "latency_ms": 5.23
    },
    "migrations_current": {
      "status": "in_progress",
      "pending_migrations": 5
    },
    "sample_query_works": {
      "status": "healthy",
      "query_time_ms": 2.45
    }
  },
  "migration_in_progress": true,
  "timestamp": "2025-11-24T10:30:00Z"
}
```

**Error Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "checks": {
    "database_reachable": {
      "status": "unhealthy",
      "error": "Connection timeout"
    },
    "migrations_current": {
      "status": "unhealthy",
      "error": "Cannot check migration status"
    },
    "sample_query_works": {
      "status": "unhealthy",
      "error": "Query failed: Table doesn't exist"
    }
  },
  "migration_in_progress": false,
  "timestamp": "2025-11-24T10:30:00Z"
}
```

**Fields:**
- `status` (string): Overall migration status
  - `"healthy"` - All migrations complete, database healthy
  - `"migration_in_progress"` - Migration currently running
  - `"unhealthy"` - Database issues or migration failures
- `checks` (object): Individual check results
  - `database_reachable` (object):
    - `status` (string): "healthy" or "unhealthy"
    - `latency_ms` (float): Connection latency
    - `error` (string, optional): Error message
  - `migrations_current` (object):
    - `status` (string): "healthy", "in_progress", or "unhealthy"
    - `pending_migrations` (integer): Number of pending migrations
    - `error` (string, optional): Error message
  - `sample_query_works` (object):
    - `status` (string): "healthy" or "unhealthy"
    - `query_time_ms` (float): Query execution time
    - `error` (string, optional): Error message
- `migration_in_progress` (boolean): Whether migration is currently running
- `timestamp` (string): ISO8601 timestamp

**Status Codes:**
- `200 OK` - Database healthy, all migrations complete
- `206 Partial Content` - Migration in progress
- `503 Service Unavailable` - Database unreachable or migration failed
- `401 Unauthorized` - Authentication required (production only)
- `403 Forbidden` - Invalid credentials

**Use Cases:**
- Monitor migration progress
- Verify database health during migration
- Automated migration status checks
- Pre-deployment readiness verification
- Rollback decision support

**Example:**
```bash
# Development
curl http://localhost:3000/health/migration

# Production
curl -u monitor:secret https://example.com/health/migration

# Check if migration is complete (exit code 0 if 200 OK)
curl -f -u monitor:secret https://example.com/health/migration
```

---

## Response Status Code Summary

| Endpoint | Status Code | Meaning |
|----------|-------------|---------|
| `/health` | 200 OK | Application is running |
| `/health/deep` | 200 OK | All dependencies healthy |
| `/health/deep` | 503 Service Unavailable | One or more dependencies unhealthy |
| `/health/migration` | 200 OK | Database healthy, migrations complete |
| `/health/migration` | 206 Partial Content | Migration in progress |
| `/health/migration` | 503 Service Unavailable | Database issues or migration failed |
| All | 401 Unauthorized | Authentication required (production) |
| All | 403 Forbidden | Invalid credentials or missing config |

---

## Integration Examples

### Load Balancer Health Check

**AWS Application Load Balancer:**
```yaml
HealthCheck:
  Enabled: true
  HealthCheckPath: /health
  HealthCheckProtocol: HTTP
  HealthCheckIntervalSeconds: 30
  HealthCheckTimeoutSeconds: 5
  HealthyThresholdCount: 2
  UnhealthyThresholdCount: 3
  Matcher:
    HttpCode: 200
```

**Kubernetes Liveness Probe:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Kubernetes Readiness Probe:**
```yaml
readinessProbe:
  httpGet:
    path: /health/deep
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

### Monitoring Integration

**Prometheus Blackbox Exporter:**
```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: [200]
      method: GET
      basic_auth:
        username: monitor
        password: secret
      fail_if_not_matches_regexp:
        - '"status":"healthy"'
```

**Nagios Check:**
```bash
#!/bin/bash
# check_health.sh
ENDPOINT="https://example.com/health/migration"
USERNAME="monitor"
PASSWORD="secret"

RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" -w "\n%{http_code}" "$ENDPOINT")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "OK - Database healthy, migrations complete"
  exit 0
elif [ "$HTTP_CODE" -eq 206 ]; then
  echo "WARNING - Migration in progress"
  exit 1
else
  echo "CRITICAL - Database unhealthy (HTTP $HTTP_CODE)"
  exit 2
fi
```

### CI/CD Pipeline Integration

**GitHub Actions:**
```yaml
- name: Check Application Health
  run: |
    curl -f http://localhost:3000/health || exit 1
    curl -f -u monitor:secret http://localhost:3000/health/deep || exit 1

- name: Wait for Migration Complete
  run: |
    timeout 300 bash -c 'until curl -f http://localhost:3000/health/migration; do sleep 5; done'
```

**GitLab CI:**
```yaml
health_check:
  stage: verify
  script:
    - curl -f http://localhost:3000/health
    - curl -f -u $MONITOR_USER:$MONITOR_PASS http://localhost:3000/health/deep
```

### Shell Script Monitoring

**Wait for Migration:**
```bash
#!/bin/bash
# wait_for_migration.sh

ENDPOINT="http://localhost:3000/health/migration"
MAX_WAIT=600  # 10 minutes
INTERVAL=5

elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ENDPOINT")

  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Migration complete!"
    exit 0
  elif [ "$HTTP_CODE" -eq 206 ]; then
    echo "Migration in progress... (${elapsed}s elapsed)"
  else
    echo "ERROR: Migration failed (HTTP $HTTP_CODE)"
    exit 1
  fi

  sleep $INTERVAL
  elapsed=$((elapsed + INTERVAL))
done

echo "ERROR: Migration timed out after ${MAX_WAIT}s"
exit 1
```

---

## Best Practices

### Load Balancer Configuration

1. **Use `/health` for load balancer checks**
   - Fast response time
   - No authentication required
   - Minimal resource usage

2. **Set appropriate timeouts**
   - Health check timeout: 5s
   - Health check interval: 10-30s
   - Healthy threshold: 2 consecutive successes
   - Unhealthy threshold: 3 consecutive failures

### Migration Monitoring

1. **Before Migration:**
   - Verify `/health/migration` returns 200 OK
   - Ensure database is healthy
   - Check no pending migrations exist

2. **During Migration:**
   - Monitor `/health/migration` for 206 status
   - Check migration logs: `log/migration.log`
   - Watch Grafana dashboard for progress

3. **After Migration:**
   - Verify `/health/migration` returns 200 OK
   - Confirm `pending_migrations: 0`
   - Run `/health/deep` for full verification

### Security

1. **Protect Sensitive Endpoints:**
   - Always enable authentication in production
   - Use strong, randomly generated passwords
   - Rotate credentials regularly
   - Use HTTPS in production

2. **Monitoring Credentials:**
   ```bash
   # Generate strong password
   openssl rand -base64 32

   # Set environment variables
   export MONITOR_USERNAME="monitor"
   export MONITOR_PASSWORD="$(openssl rand -base64 32)"
   ```

3. **IP Whitelisting (Optional):**
   - Restrict `/health/deep` and `/health/migration` to monitoring IPs
   - Use firewall rules or application-level restrictions

### Alerting

Set up alerts based on health check failures:

- **Critical:** `/health` fails (application down)
- **Critical:** `/health/deep` database check fails
- **Warning:** `/health/migration` returns 206 for > 30 minutes
- **Critical:** `/health/migration` returns 503

---

## Troubleshooting

### Health Check Returns 401/403

**Problem:** Authentication required but not provided or invalid.

**Solution:**
```bash
# Check environment variables are set
echo $MONITOR_USERNAME
echo $MONITOR_PASSWORD

# Provide credentials in request
curl -u $MONITOR_USERNAME:$MONITOR_PASSWORD http://localhost:3000/health/deep
```

### Database Check Fails

**Problem:** Database connectivity issues.

**Steps to diagnose:**
1. Check database server is running
2. Verify connection credentials in `config/database.yml`
3. Test connection manually: `mysql -h host -u user -p`
4. Check firewall rules
5. Review database logs

### Migration Shows In Progress Indefinitely

**Problem:** Migration stuck or stalled.

**Steps to diagnose:**
1. Check migration logs: `tail -f log/migration.log`
2. Check for database locks: `SHOW PROCESSLIST;`
3. Review application logs for errors
4. Check system resources (CPU, memory, I/O)
5. Consider manual intervention if truly stuck

### Sample Query Fails

**Problem:** Database accessible but queries fail.

**Possible causes:**
- Table doesn't exist (mid-migration)
- Permissions issue
- Database corruption

**Steps to diagnose:**
1. Check which query is failing in logs
2. Run query manually in database console
3. Verify table schema
4. Check user permissions

---

## Additional Resources

- [Grafana Dashboard Setup](../observability/grafana-setup.md)
- [Alerting Configuration](../observability/alerting.md)
- [Prometheus Metrics](../observability/metrics.md)
- [Migration Runbook](../runbooks/mysql8-migration.md)
