# Production Migration Runbook - MySQL 8 Database Unification

**Feature ID**: FEAT-DB-001
**Document Version**: 1.0
**Created**: 2025-11-24
**Migration Date**: [TO BE SCHEDULED]

---

## Table of Contents

1. [Overview](#1-overview)
2. [Pre-Migration Checklist](#2-pre-migration-checklist)
3. [Team Roles and Responsibilities](#3-team-roles-and-responsibilities)
4. [Timeline](#4-timeline)
5. [Detailed Migration Steps](#5-detailed-migration-steps)
6. [Verification Checkpoints](#6-verification-checkpoints)
7. [Rollback Triggers](#7-rollback-triggers)
8. [Rollback Procedure](#8-rollback-procedure)
9. [Post-Migration Monitoring](#9-post-migration-monitoring)
10. [Communication Plan](#10-communication-plan)
11. [Appendix](#11-appendix)

---

## 1. Overview

### 1.1 Migration Objective

Migrate production database from PostgreSQL to MySQL 8.0+ to achieve environment parity across all environments (development, test, production) and eliminate database-specific compatibility issues.

### 1.2 Success Criteria

- ✅ 100% of production data migrated without loss
- ✅ All 5 tables successfully migrated: alarm_contents, contents, feedbacks, line_groups, operators
- ✅ Maintenance mode downtime < 30 minutes
- ✅ All smoke tests passing post-migration
- ✅ No critical errors in application logs
- ✅ Database performance metrics within acceptable range

### 1.3 Migration Approach

**Tool**: pgloader (PostgreSQL to MySQL migration)
**Method**: Full data migration during maintenance window
**Fallback**: Automated rollback to PostgreSQL if issues occur

### 1.4 Key Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Data Accuracy | 100% | Row count comparison |
| Downtime | < 30 min | Maintenance window duration |
| Query Performance | 95th percentile < 200ms | Application monitoring |
| Error Rate | < 0.1% | Error tracking logs |
| Rollback Time | < 10 min | Timed execution |

---

## 2. Pre-Migration Checklist

**Verify ALL items before proceeding to migration:**

### 2.1 Infrastructure Readiness

- [ ] **MySQL 8 instance provisioned and accessible**
  - Verify: `mysql -h $MYSQL_HOST -u $MYSQL_USER -p -e "SELECT VERSION();"`
  - Expected: MySQL 8.0.34 or higher
  - Contact: DevOps team

- [ ] **Database users created with correct permissions**
  - Application user: `reline_app` (SELECT, INSERT, UPDATE, DELETE)
  - Migration user: `reline_migrate` (ALL PRIVILEGES)
  - Verify: `SHOW GRANTS FOR 'reline_app'@'%';`

- [ ] **SSL/TLS certificates configured**
  - Certificate paths: `/etc/mysql/certs/` on server
  - Environment variables set: DB_SSL_CA, DB_SSL_KEY, DB_SSL_CERT
  - Verify: `SHOW VARIABLES LIKE '%ssl%';`

### 2.2 Staging Validation

- [ ] **Staging migration completed successfully**
  - Staging migration date: [FILL IN]
  - Migration duration: [FILL IN]
  - Data verification: ✅ All row counts matched
  - Report: `docs/migration/staging-migration-report.md`

- [ ] **All tests passing on staging MySQL 8**
  - RSpec results: [FILL IN]
  - System tests: ✅ PASSED
  - Coverage: >= 90%

- [ ] **Performance benchmarks met on staging**
  - 95th percentile query time: [FILL IN] ms (target: < 200ms)
  - Load test: 1000 requests completed successfully
  - Report: `docs/performance/mysql8-benchmarks.md`

### 2.3 Rollback Preparation

- [ ] **Rollback script tested on staging**
  - Script location: `scripts/rollback_to_postgresql.sh`
  - Test execution time: [FILL IN] min (target: < 10 min)
  - Test result: ✅ SUCCESSFUL

- [ ] **PostgreSQL backups verified**
  - Latest backup date: [FILL IN]
  - Backup location: [FILL IN]
  - Backup size: [FILL IN] GB
  - Backup restoration tested: ✅ YES

### 2.4 Operational Readiness

- [ ] **Maintenance window scheduled**
  - Scheduled date/time: [FILL IN]
  - Duration: 2-3 hours (30 min maintenance mode)
  - Approved by: [FILL IN]

- [ ] **Team notified of migration plan**
  - Notification sent: [DATE]
  - All team members confirmed availability
  - On-call schedule defined

- [ ] **Monitoring and alerting configured**
  - Prometheus metrics: ✅ Configured
  - Grafana dashboard: ✅ Ready
  - Alert rules: ✅ Active
  - Health check endpoints: ✅ Working

### 2.5 Final Verification

- [ ] **Pre-deployment checklist verified**
  - Document: `docs/migration/pre-deployment-verification.md`
  - All 11 items checked
  - Sign-off by: [TEAM LEAD NAME]

---

## 3. Team Roles and Responsibilities

### 3.1 Migration Team

| Role | Name | Responsibilities | Contact |
|------|------|------------------|---------|
| **Migration Lead** | [FILL IN] | Overall coordination, go/no-go decision | [PHONE/SLACK] |
| **Database Engineer** | [FILL IN] | Execute migration scripts, verify data | [PHONE/SLACK] |
| **Backend Engineer** | [FILL IN] | Application deployment, smoke tests | [PHONE/SLACK] |
| **DevOps Engineer** | [FILL IN] | Infrastructure, monitoring, rollback | [PHONE/SLACK] |
| **QA Engineer** | [FILL IN] | Testing, verification | [PHONE/SLACK] |

### 3.2 On-Call Support

| Role | Name | Contact |
|------|------|---------|
| **Primary On-Call** | [FILL IN] | [PHONE/SLACK] |
| **Secondary On-Call** | [FILL IN] | [PHONE/SLACK] |
| **Escalation Contact** | [FILL IN] | [PHONE/SLACK] |

### 3.3 Communication Channels

- **Primary**: Slack channel: `#migration-mysql8`
- **Voice**: Conference call: [LINK/NUMBER]
- **Status Updates**: Every 15 minutes during migration
- **Emergency Escalation**: [PHONE NUMBER]

---

## 4. Timeline

**Total Estimated Time**: 2-3 hours (including preparation and monitoring)
**Maintenance Mode Duration**: 30 minutes (target), 60 minutes (maximum)

### 4.1 Detailed Timeline

| Time | Duration | Phase | Activity | Owner |
|------|----------|-------|----------|-------|
| **T-30** | 30 min | Preparation | Final verification, team standup | Migration Lead |
| **T-15** | 15 min | Preparation | Pre-migration checks, backup verification | Database Engineer |
| **T+0** | 5 min | **START** | Enable maintenance mode | DevOps Engineer |
| **T+5** | 10 min | Backup | Create final PostgreSQL backup | Database Engineer |
| **T+15** | 15 min | Migration | Execute pgloader (data migration) | Database Engineer |
| **T+30** | 10 min | Verification | Verify row counts and data integrity | Database Engineer |
| **T+40** | 10 min | Configuration | Update database.yml, bundle install | Backend Engineer |
| **T+50** | 10 min | Deployment | Restart application with MySQL 8 | DevOps Engineer |
| **T+60** | 10 min | Testing | Run smoke tests | QA Engineer |
| **T+70** | 10 min | Monitoring | Check health endpoints, logs, metrics | DevOps Engineer |
| **T+80** | 5 min | **COMPLETE** | Disable maintenance mode | DevOps Engineer |
| **T+85** | 60 min | Monitoring | Watch for errors, performance issues | All team |

### 4.2 Checkpoint Timeline

| Checkpoint | Time | Success Criteria | Rollback Trigger |
|------------|------|------------------|------------------|
| **CP-1**: Backup Created | T+15 | Backup file size > 0, verified | Backup creation fails |
| **CP-2**: Data Migrated | T+30 | pgloader exits with status 0 | pgloader errors |
| **CP-3**: Data Verified | T+40 | All row counts match 100% | Row count mismatch > 0.1% |
| **CP-4**: App Deployed | T+60 | Rails server starts successfully | Deploy fails |
| **CP-5**: Tests Passing | T+70 | All smoke tests green | Critical test failures |
| **CP-6**: Monitoring OK | T+80 | No critical alerts, error rate < 0.1% | Critical alerts |

---

## 5. Detailed Migration Steps

### Step 1: Enable Maintenance Mode (T+0)

**Owner**: DevOps Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Navigate to application directory
cd /path/to/reline-app

# 2. Enable maintenance mode
touch tmp/maintenance.txt

# 3. Verify maintenance mode is active
curl -I http://localhost:3000
# Expected: HTTP/1.1 503 Service Unavailable

# 4. Announce in Slack
echo "✅ Maintenance mode enabled at $(date)" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- Application returns HTTP 503 status
- Maintenance page displayed to users
- All team members notified

**Troubleshooting**:
- If maintenance page not showing: Check middleware configuration
- If curl fails: Verify Rails server is running

---

### Step 2: Create Final PostgreSQL Backup (T+5)

**Owner**: Database Engineer
**Duration**: 10 minutes

**Commands**:
```bash
# 1. Set timestamp for backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_postgresql_production_${TIMESTAMP}.sql"

# 2. Create backup
pg_dump \
  -h $PG_HOST \
  -U $PG_USER \
  -d reline_production \
  -F c \
  -f $BACKUP_FILE

# 3. Verify backup file created
ls -lh $BACKUP_FILE
# Expected: File size > 0 (should be several MB at least)

# 4. Calculate backup checksum
sha256sum $BACKUP_FILE > ${BACKUP_FILE}.sha256

# 5. Test backup integrity
pg_restore -l $BACKUP_FILE | head -n 20
# Expected: List of tables including alarm_contents, contents, feedbacks, line_groups, operators

# 6. Copy backup to safe location
cp $BACKUP_FILE /backup/production/
cp ${BACKUP_FILE}.sha256 /backup/production/

# 7. Log backup completion
echo "✅ PostgreSQL backup created: $BACKUP_FILE ($(ls -lh $BACKUP_FILE | awk '{print $5}'))" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- Backup file created successfully
- File size > 0 (typical: 10-100 MB depending on data)
- Backup contains all 5 tables
- Checksum file created
- Backup copied to safe storage

**Troubleshooting**:
- If pg_dump fails with "connection refused": Check PostgreSQL is running
- If backup size is 0: Check database connection parameters
- If "permission denied": Check user has SELECT privileges

**Rollback Trigger**:
- If backup creation fails, ABORT migration immediately

---

### Step 3: Verify Backup Integrity (T+10)

**Owner**: Database Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Verify backup checksum
sha256sum -c ${BACKUP_FILE}.sha256
# Expected: backup_postgresql_production_TIMESTAMP.sql: OK

# 2. Count tables in backup
pg_restore -l $BACKUP_FILE | grep "TABLE DATA" | wc -l
# Expected: 5 (alarm_contents, contents, feedbacks, line_groups, operators)

# 3. Verify backup is not corrupted
pg_restore --list $BACKUP_FILE > /dev/null
echo $?
# Expected: 0 (success)

# 4. Log verification
echo "✅ Backup integrity verified" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- Checksum matches
- All 5 tables present in backup
- No corruption detected

**Rollback Trigger**:
- If backup verification fails, ABORT migration

---

### Step 4: Execute Data Migration (pgloader) (T+15)

**Owner**: Database Engineer
**Duration**: 15 minutes

**Commands**:
```bash
# 1. Create pgloader configuration
cat > migration.load <<'EOF'
LOAD DATABASE
     FROM postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST/reline_production
     INTO mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST/reline_production

WITH include drop, create tables, create indexes, reset sequences,
     workers = 8, concurrency = 1,
     multiple readers per thread, rows per range = 50000

SET MySQL PARAMETERS
    net_read_timeout  = '120',
    net_write_timeout = '120'

CAST type datetime to datetime drop default drop not null using zero-dates-to-null,
     type timestamp to datetime drop default drop not null using zero-dates-to-null

BEFORE LOAD DO
     $$ ALTER DATABASE reline_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; $$;
EOF

# 2. Substitute environment variables
envsubst < migration.load > migration_runtime.load

# 3. Execute migration
pgloader migration_runtime.load 2>&1 | tee migration_output.log

# 4. Check exit status
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "✅ pgloader completed successfully"
else
  echo "❌ pgloader failed with exit code ${PIPESTATUS[0]}"
  exit 1
fi

# 5. Log migration completion
echo "✅ Data migration completed at $(date)" | slack-cli --channel migration-mysql8
```

**Expected Output**:
```
table name           errors       rows      bytes      total time
--------------------  -----  ---------  ---------  --------------
            fetch        0          0                     0.000s
     alarm_contents      0        XXX     XX.X kB         X.XXXs
           contents      0        XXX     XX.X kB         X.XXXs
          feedbacks      0        XXX     XX.X kB         X.XXXs
        line_groups      0        XXX     XX.X kB         X.XXXs
          operators      0        XXX     XX.X kB         X.XXXs
--------------------  -----  ---------  ---------  --------------
Total                    0      XXXXX    XXX.X kB        XX.XXXs
```

**Success Criteria**:
- pgloader exits with status 0
- "errors" column shows 0 for all tables
- "rows" column shows expected counts
- No "FATAL" or "ERROR" messages in output
- Migration completes in < 15 minutes

**Troubleshooting**:
- **Error: "connection refused"**: Check MySQL server is running and accessible
- **Error: "authentication failed"**: Verify MySQL credentials in environment variables
- **Error: "table already exists"**: Ensure MySQL database is empty before migration
- **Error: "timeout"**: Increase net_read_timeout and net_write_timeout values
- **Slow migration (> 15 min)**: Check network bandwidth, consider increasing workers

**Rollback Trigger**:
- If pgloader exits with non-zero status, ABORT and rollback
- If migration takes > 30 minutes, consider aborting (decision by Migration Lead)

---

### Step 5: Verify Row Counts (T+30)

**Owner**: Database Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Run verification script
cd /path/to/reline-app
RAILS_ENV=production bundle exec ruby lib/database_migration/verify_migration.rb

# Expected output:
# ✅ alarm_contents: XXX rows (match)
# ✅ contents: XXX rows (match)
# ✅ feedbacks: XXX rows (match)
# ✅ line_groups: XXX rows (match)
# ✅ operators: XXX rows (match)
# ✅ All tables verified successfully

# 2. Check exit status
if [ $? -eq 0 ]; then
  echo "✅ Row count verification PASSED"
else
  echo "❌ Row count verification FAILED - ROLLBACK REQUIRED"
  exit 1
fi

# 3. Log verification results
echo "✅ Data verification completed at $(date)" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- All 5 tables show row count match
- No mismatches reported
- Script exits with status 0

**Verification Details**:
| Table | PostgreSQL Count | MySQL Count | Status |
|-------|------------------|-------------|--------|
| alarm_contents | [AUTO] | [AUTO] | ✅/❌ |
| contents | [AUTO] | [AUTO] | ✅/❌ |
| feedbacks | [AUTO] | [AUTO] | ✅/❌ |
| line_groups | [AUTO] | [AUTO] | ✅/❌ |
| operators | [AUTO] | [AUTO] | ✅/❌ |

**Rollback Trigger**:
- **CRITICAL**: If any row count mismatch > 0.1%, ABORT and rollback immediately
- Do NOT proceed if data verification fails

---

### Step 6: Verify Data Integrity (T+35)

**Owner**: Database Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Verify indexes created
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SHOW INDEX FROM line_groups WHERE Key_name = 'index_line_groups_on_line_group_id';
"
# Expected: 1 row showing unique index

# 2. Verify foreign key constraints (if any)
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'reline_production';
"

# 3. Verify character set and collation
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SELECT TABLE_NAME, TABLE_COLLATION
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'reline_production';
"
# Expected: All tables show utf8mb4_unicode_ci

# 4. Test sample query
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SELECT id, email, name FROM operators LIMIT 5;
"
# Expected: Returns sample data, no errors

# 5. Verify unique constraints
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SELECT COUNT(*) as count, line_group_id
FROM line_groups
GROUP BY line_group_id
HAVING COUNT(*) > 1;
"
# Expected: Empty result (no duplicates)

echo "✅ Data integrity checks completed" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- All indexes created correctly
- Character set: utf8mb4
- Collation: utf8mb4_unicode_ci
- Sample queries return data
- No duplicate values in unique columns

**Troubleshooting**:
- **Missing indexes**: Re-run migrations with `rails db:migrate`
- **Wrong collation**: May need to recreate tables with correct collation
- **Duplicate values**: Data quality issue, investigate source

---

### Step 7: Update Application Configuration (T+40)

**Owner**: Backend Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Navigate to application directory
cd /path/to/reline-app

# 2. Checkout MySQL configuration (should already be in repo)
git status
# Verify config/database.yml and Gemfile are ready

# 3. Set production environment variables
export DB_HOST=$MYSQL_HOST
export DB_PORT=3306
export DB_NAME=reline_production
export DB_USERNAME=reline_app
export DB_PASSWORD=$MYSQL_APP_PASSWORD
export DB_SSL_CA=/etc/mysql/certs/ca-cert.pem
export DB_SSL_KEY=/etc/mysql/certs/client-key.pem
export DB_SSL_CERT=/etc/mysql/certs/client-cert.pem

# 4. Verify environment variables
env | grep DB_
# Verify all DB_* variables are set correctly

# 5. Update environment file (if using dotenv)
# Ensure production .env file has MySQL credentials

echo "✅ Configuration updated" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- All environment variables set
- Configuration files ready
- No syntax errors in YAML files

---

### Step 8: Verify Database Connection (T+45)

**Owner**: Backend Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Test database connection
cd /path/to/reline-app
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name"
# Expected: Mysql2

# 2. Verify database version
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.select_value('SELECT VERSION()')"
# Expected: 8.0.XX

# 3. Check migrations status
RAILS_ENV=production bundle exec rails db:version
# Expected: Current version: XXXXXXXXXX

# 4. Verify SSL connection
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.select_value('SHOW STATUS LIKE \"Ssl_cipher\"')"
# Expected: Non-empty cipher value (e.g., TLS_AES_256_GCM_SHA384)

# 5. Test sample query
RAILS_ENV=production bundle exec rails runner "puts Operator.count"
# Expected: Number of operators (should match verification count)

echo "✅ Database connection verified" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- Rails connects to MySQL successfully
- Adapter name is "Mysql2"
- SSL connection active
- Sample queries work

**Troubleshooting**:
- **Error: "Can't connect to MySQL"**: Check DB_HOST and firewall rules
- **Error: "Access denied"**: Verify DB_USERNAME and DB_PASSWORD
- **Error: "SSL connection error"**: Check SSL certificate paths
- **Wrong adapter**: Check database.yml configuration

**Rollback Trigger**:
- If Rails cannot connect to MySQL, ABORT and rollback

---

### Step 9: Restart Application (T+50)

**Owner**: DevOps Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Stop application (method depends on deployment)
# Example for systemd:
sudo systemctl stop reline-app

# Wait 5 seconds
sleep 5

# 2. Verify application stopped
sudo systemctl status reline-app
# Expected: inactive (dead)

# 3. Start application with MySQL configuration
sudo systemctl start reline-app

# 4. Wait for application to start
sleep 10

# 5. Verify application started
sudo systemctl status reline-app
# Expected: active (running)

# 6. Check application logs
tail -n 50 /var/log/reline/production.log
# Look for:
# - "Mysql2" adapter confirmation
# - No connection errors
# - Application initialized successfully

echo "✅ Application restarted at $(date)" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- Application process running
- Rails server started successfully
- Logs show MySQL connection
- No critical errors in logs

**Troubleshooting**:
- **App won't start**: Check logs for configuration errors
- **Port already in use**: Kill old processes
- **Database connection error**: Verify Step 8 again
- **Permission errors**: Check file permissions

**Rollback Trigger**:
- If application fails to start after 3 attempts, ABORT and rollback

---

### Step 10: Run Smoke Tests (T+60)

**Owner**: QA Engineer
**Duration**: 10 minutes

**Commands**:
```bash
# 1. Health check endpoint
curl -f http://localhost:3000/health
# Expected: {"status":"ok","database":{"adapter":"Mysql2",...}}

# 2. Database health check
curl -f http://localhost:3000/health/migration
# Expected: {"migration_in_progress":false,"current_database":{"adapter":"Mysql2",...}}

# 3. Run critical smoke tests
cd /path/to/reline-app

# Test 1: Operator authentication
RAILS_ENV=production bundle exec rspec spec/models/operator_spec.rb --tag smoke
# Expected: All tests pass

# Test 2: LINE group operations
RAILS_ENV=production bundle exec rspec spec/models/line_group_spec.rb --tag smoke
# Expected: All tests pass

# Test 3: Content management
RAILS_ENV=production bundle exec rspec spec/models/content_spec.rb --tag smoke
# Expected: All tests pass

# 4. Manual smoke tests
# - Operator login: [TEST MANUALLY]
# - View LINE groups: [TEST MANUALLY]
# - Create content: [TEST MANUALLY]
# - Submit feedback: [TEST MANUALLY]

echo "✅ Smoke tests completed" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- All health check endpoints return 200 OK
- All automated smoke tests pass
- Manual smoke tests successful
- No errors in application logs

**Smoke Test Checklist**:
- [ ] Health check endpoint responds
- [ ] Database adapter is Mysql2
- [ ] Operator authentication works
- [ ] LINE group listing works
- [ ] Content CRUD operations work
- [ ] Feedback submission works
- [ ] No JavaScript errors in browser console

**Rollback Trigger**:
- If critical smoke tests fail, consider rollback (decision by Migration Lead)

---

### Step 11: Verify Monitoring and Metrics (T+70)

**Owner**: DevOps Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Check Prometheus metrics endpoint
curl http://localhost:3000/metrics | grep database_pool
# Expected: database_pool_size, database_pool_available metrics present

# 2. Check Grafana dashboard
# Open: http://grafana.example.com/d/mysql8-migration
# Verify:
# - Database connection pool graph showing data
# - Query performance graph showing data
# - No alerts firing

# 3. Check application error rate
curl -s http://prometheus.example.com/api/v1/query?query=rate(http_requests_total{status=~"5.."}[5m])
# Expected: Error rate < 0.1%

# 4. Check database query performance
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SHOW FULL PROCESSLIST;
"
# Expected: No long-running queries (> 5 seconds)

# 5. Check for alerts
# Check Slack #alerts channel or email
# Expected: No critical alerts

echo "✅ Monitoring verified" | slack-cli --channel migration-mysql8
```

**Success Criteria**:
- Prometheus metrics being collected
- Grafana dashboard showing live data
- No critical alerts firing
- Query performance within acceptable range
- Error rate < 0.1%

**Monitoring Checklist**:
- [ ] Prometheus scraping metrics
- [ ] Grafana dashboard accessible
- [ ] Connection pool metrics healthy (< 80% usage)
- [ ] Query performance acceptable (95th percentile < 200ms)
- [ ] No critical alerts
- [ ] Error rate within limits

---

### Step 12: Disable Maintenance Mode (T+80)

**Owner**: DevOps Engineer
**Duration**: 5 minutes

**Commands**:
```bash
# 1. Remove maintenance mode file
cd /path/to/reline-app
rm tmp/maintenance.txt

# 2. Verify maintenance mode disabled
curl -I http://localhost:3000
# Expected: HTTP/1.1 200 OK (or 302 redirect)

# 3. Test user-facing endpoint
curl -I http://production-url.example.com
# Expected: HTTP/1.1 200 OK (not 503)

# 4. Announce completion
echo "✅ Maintenance mode disabled at $(date) - Application is LIVE on MySQL 8" | slack-cli --channel migration-mysql8
echo "🎉 Migration completed successfully!" | slack-cli --channel general

# 5. Update status page (if applicable)
# [Manual step - update status page to "All Systems Operational"]
```

**Success Criteria**:
- Maintenance page no longer displayed
- Application accessible to users
- Status page updated
- Team notified

---

## 6. Verification Checkpoints

### 6.1 Critical Checkpoints Summary

| Checkpoint | When | What to Verify | Pass Criteria | Fail Action |
|------------|------|----------------|---------------|-------------|
| **CP-1**: Backup | T+15 | PostgreSQL backup created | File size > 0, checksum valid | ABORT |
| **CP-2**: Migration | T+30 | pgloader completed | Exit code 0, no errors | ABORT + ROLLBACK |
| **CP-3**: Data Verification | T+40 | Row counts match | 100% match all tables | ABORT + ROLLBACK |
| **CP-4**: Connection | T+50 | Rails connects to MySQL | Connection successful | ABORT + ROLLBACK |
| **CP-5**: Application | T+60 | App running on MySQL | Server started, no errors | ROLLBACK |
| **CP-6**: Smoke Tests | T+70 | Critical features work | All tests pass | Consider rollback |
| **CP-7**: Monitoring | T+80 | Metrics and logs healthy | No critical alerts | Monitor closely |

### 6.2 Detailed Verification Script

**Script**: `scripts/verify_migration_checkpoint.sh`

```bash
#!/bin/bash
# Migration checkpoint verification script

CHECKPOINT=$1

case $CHECKPOINT in
  backup)
    # Verify backup file exists and has content
    if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
      echo "✅ CP-1: Backup verification PASSED"
      exit 0
    else
      echo "❌ CP-1: Backup verification FAILED"
      exit 1
    fi
    ;;

  migration)
    # Verify pgloader exit status
    if grep -q "errors 0" migration_output.log; then
      echo "✅ CP-2: Migration verification PASSED"
      exit 0
    else
      echo "❌ CP-2: Migration verification FAILED"
      exit 1
    fi
    ;;

  data)
    # Run row count verification
    RAILS_ENV=production bundle exec ruby lib/database_migration/verify_migration.rb
    exit $?
    ;;

  connection)
    # Verify Rails can connect to MySQL
    ADAPTER=$(RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name")
    if [ "$ADAPTER" = "Mysql2" ]; then
      echo "✅ CP-4: Connection verification PASSED"
      exit 0
    else
      echo "❌ CP-4: Connection verification FAILED (adapter: $ADAPTER)"
      exit 1
    fi
    ;;

  application)
    # Verify application is running
    if systemctl is-active --quiet reline-app; then
      echo "✅ CP-5: Application verification PASSED"
      exit 0
    else
      echo "❌ CP-5: Application verification FAILED"
      exit 1
    fi
    ;;

  smoke)
    # Run smoke tests
    RAILS_ENV=production bundle exec rspec spec/ --tag smoke
    exit $?
    ;;

  monitoring)
    # Check for critical alerts
    ALERTS=$(curl -s http://prometheus:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing" and .labels.severity=="critical") | .labels.alertname' | wc -l)
    if [ "$ALERTS" -eq 0 ]; then
      echo "✅ CP-7: Monitoring verification PASSED"
      exit 0
    else
      echo "❌ CP-7: Monitoring verification FAILED ($ALERTS critical alerts)"
      exit 1
    fi
    ;;

  *)
    echo "Usage: $0 {backup|migration|data|connection|application|smoke|monitoring}"
    exit 1
    ;;
esac
```

---

## 7. Rollback Triggers

### 7.1 When to Rollback

**ABORT migration immediately and execute rollback if ANY of these occur:**

#### Critical Triggers (Immediate Rollback)

1. **Data Loss Risk**
   - Row count mismatch > 0.1% in verification
   - pgloader reports errors for any table
   - Data integrity check fails

2. **Time Overrun**
   - Migration exceeds 30-minute maintenance window
   - pgloader running for > 30 minutes with no progress

3. **Application Failure**
   - Rails cannot connect to MySQL after 3 attempts
   - Application fails to start after configuration update
   - Critical smoke tests fail (authentication, database operations)

4. **Infrastructure Issues**
   - MySQL server becomes unreachable
   - Database connection pool exhausted
   - Disk space critical on MySQL server

5. **Data Integrity Issues**
   - Duplicate values in unique columns
   - Missing indexes or constraints
   - Character encoding corruption detected

#### Warning Triggers (Consider Rollback)

6. **Performance Degradation**
   - Query performance > 500ms (95th percentile)
   - Error rate > 1%
   - Multiple critical alerts firing

7. **Partial Functionality**
   - Non-critical features not working
   - Some smoke tests failing
   - High warning-level alert count

### 7.2 Decision Tree

```
                      Issue Detected
                            |
                    ┌───────┴───────┐
                    |               |
              Critical         Warning
                    |               |
         ┌──────────┘       Migration Lead Decision
         |                          |
    ROLLBACK              ┌─────────┴─────────┐
    IMMEDIATELY           |                   |
                     Continue            Rollback
                     + Monitor        (Conservative)
```

### 7.3 Go/No-Go Decision Authority

| Trigger Type | Decision Authority | Action |
|--------------|-------------------|---------|
| Critical (Data Loss) | **Automatic** | ROLLBACK immediately |
| Critical (Time/App) | **Database Engineer** | ROLLBACK without approval needed |
| Warning | **Migration Lead** | Consult team, make decision |
| Multiple Warnings | **Migration Lead** | Escalate to management |

---

## 8. Rollback Procedure

### 8.1 Rollback Overview

**Tool**: Automated rollback script
**Script**: `scripts/rollback_to_postgresql.sh`
**Duration**: < 10 minutes
**Impact**: Application downtime continues until rollback complete

### 8.2 Rollback Steps

#### Step 1: Announce Rollback Decision (T+0)

**Owner**: Migration Lead

```bash
# Announce in Slack
echo "⚠️  ROLLBACK INITIATED at $(date) - Reason: [FILL IN REASON]" | slack-cli --channel migration-mysql8
echo "⚠️  Migration rollback in progress" | slack-cli --channel general
```

---

#### Step 2: Execute Rollback Script (T+1)

**Owner**: DevOps Engineer

**Commands**:
```bash
# 1. Navigate to application directory
cd /path/to/reline-app

# 2. Execute rollback script
bash scripts/rollback_to_postgresql.sh

# Expected output:
# 🔄 Starting rollback to PostgreSQL...
# ✅ Application stopped
# ✅ Configuration reverted to PostgreSQL
# ✅ Bundle installed
# ✅ PostgreSQL connection verified
# ✅ Application restarted
# ✅ Rollback complete. Application running on PostgreSQL.
```

**Rollback Script Contents** (`scripts/rollback_to_postgresql.sh`):

```bash
#!/bin/bash
set -e

echo "🔄 Starting rollback to PostgreSQL..."

# 1. Stop application
echo "Stopping application..."
sudo systemctl stop reline-app
echo "✅ Application stopped"

# 2. Revert database.yml to PostgreSQL
echo "Reverting configuration files..."
git checkout HEAD -- config/database.yml Gemfile Gemfile.lock
echo "✅ Configuration reverted to PostgreSQL"

# 3. Reinstall gems
echo "Running bundle install..."
bundle install --deployment --without development test
echo "✅ Bundle installed"

# 4. Verify PostgreSQL connection
echo "Verifying PostgreSQL connection..."
ADAPTER=$(RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name" 2>&1)
if echo "$ADAPTER" | grep -q "PG"; then
  echo "✅ PostgreSQL connection verified"
else
  echo "❌ ERROR: Failed to connect to PostgreSQL. Adapter: $ADAPTER"
  exit 1
fi

# 5. Restart application
echo "Restarting application..."
sudo systemctl start reline-app
sleep 10

# 6. Verify application started
if systemctl is-active --quiet reline-app; then
  echo "✅ Application restarted"
else
  echo "❌ ERROR: Application failed to start"
  exit 1
fi

# 7. Health check
HEALTH=$(curl -s http://localhost:3000/health | jq -r '.status' 2>/dev/null || echo "error")
if [ "$HEALTH" = "ok" ]; then
  echo "✅ Health check passed"
else
  echo "⚠️  WARNING: Health check returned: $HEALTH"
fi

echo "✅ Rollback complete. Application running on PostgreSQL."
```

---

#### Step 3: Verify Rollback Success (T+5)

**Owner**: Database Engineer

**Commands**:
```bash
# 1. Verify adapter
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name"
# Expected: PG

# 2. Test database query
RAILS_ENV=production bundle exec rails runner "puts Operator.count"
# Expected: Count matches pre-migration

# 3. Check health endpoint
curl http://localhost:3000/health | jq .
# Expected: {"status":"ok","database":{"adapter":"PG",...}}

# 4. Verify application logs
tail -n 100 /var/log/reline/production.log
# Look for: No errors, PostgreSQL connections
```

---

#### Step 4: Disable Maintenance Mode (T+8)

**Owner**: DevOps Engineer

```bash
# 1. Remove maintenance mode
rm tmp/maintenance.txt

# 2. Verify application accessible
curl -I http://localhost:3000
# Expected: HTTP/1.1 200 OK

# 3. Announce completion
echo "✅ Rollback completed at $(date) - Application restored on PostgreSQL" | slack-cli --channel migration-mysql8
```

---

### 8.3 Post-Rollback Actions

**Immediate (Day 0)**:
- [ ] Update status page: "Migration postponed, service restored"
- [ ] Notify stakeholders of rollback
- [ ] Begin root cause analysis
- [ ] Document issues encountered

**Short-term (Day 1-2)**:
- [ ] Team debrief meeting
- [ ] Review logs and monitoring data
- [ ] Identify fixes needed
- [ ] Update migration plan
- [ ] Test fixes on staging

**Long-term (Week 1-2)**:
- [ ] Implement fixes
- [ ] Re-test on staging
- [ ] Schedule new migration window
- [ ] Update runbook based on lessons learned

---

## 9. Post-Migration Monitoring

### 9.1 Immediate Monitoring (First Hour)

**Owner**: DevOps Engineer + Full Team

**Monitoring Checklist** (Check every 10 minutes):

- [ ] **Application Health**
  - Health endpoint returns 200 OK
  - Response time < 200ms (95th percentile)
  - No 500 errors in logs

- [ ] **Database Metrics**
  - Connection pool usage < 80%
  - Active connections stable
  - Query time < 50ms (average)
  - No slow queries (> 1 second)

- [ ] **System Resources**
  - CPU usage < 80%
  - Memory usage < 80%
  - Disk I/O normal
  - Network latency normal

- [ ] **Error Monitoring**
  - Error rate < 0.1%
  - No critical errors in Sentry/Rollbar
  - No database connection errors
  - No timeout errors

### 9.2 24-Hour Monitoring (First Day)

**Owner**: On-Call Team (Rotating)

**Monitoring Frequency**: Every 2 hours

**Metrics to Track**:

| Metric | Target | Alert Threshold | Action if Exceeded |
|--------|--------|-----------------|-------------------|
| Response Time (95th) | < 200ms | > 500ms | Investigate slow queries |
| Query Time (avg) | < 50ms | > 100ms | Check query plans |
| Error Rate | < 0.1% | > 1% | Check logs, consider rollback |
| Connection Pool | < 80% | > 90% | Increase pool size |
| CPU Usage | < 70% | > 90% | Check for inefficient queries |
| Memory Usage | < 80% | > 95% | Check for memory leaks |

**Monitoring Commands**:

```bash
# 1. Check application metrics
curl http://prometheus:9090/api/v1/query?query=http_request_duration_seconds{quantile="0.95"}

# 2. Check database queries
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production -e "
SHOW FULL PROCESSLIST;
"

# 3. Check slow query log
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -e "
SELECT * FROM mysql.slow_log ORDER BY query_time DESC LIMIT 10;
"

# 4. Check error logs
tail -f /var/log/reline/production.log | grep -i error

# 5. Check system resources
top -b -n 1 | head -n 20
```

### 9.3 Week-Long Monitoring (Days 2-7)

**Owner**: DevOps Team

**Monitoring Frequency**: Daily review

**Daily Monitoring Report Template**:

```markdown
## MySQL 8 Migration - Daily Monitoring Report
**Date**: [DATE]
**Reporter**: [NAME]
**Status**: 🟢 Healthy / 🟡 Warning / 🔴 Critical

### Key Metrics (24-hour average)
- Response Time (95th): [VALUE] ms (target: < 200ms)
- Query Time (avg): [VALUE] ms (target: < 50ms)
- Error Rate: [VALUE]% (target: < 0.1%)
- Connection Pool Usage: [VALUE]% (target: < 80%)
- Uptime: [VALUE]% (target: 99.9%)

### Incidents
- [None / List incidents with resolution]

### Performance Comparison (vs. PostgreSQL baseline)
- Response time: [+/-X%]
- Query time: [+/-X%]
- Throughput: [+/-X%]

### Action Items
- [ ] [Action item if any issues found]

### Recommendation
- ✅ Continue monitoring
- ⚠️  Investigate [specific issue]
- ❌ Consider remediation
```

### 9.4 Grafana Dashboard Monitoring

**Dashboard**: MySQL 8 Migration Monitoring
**URL**: `http://grafana.example.com/d/mysql8-migration`

**Panels to Watch**:

1. **Database Connection Pool**
   - Pool size vs available connections
   - Alert if available < 20%

2. **Query Performance**
   - 95th percentile response time
   - Alert if > 200ms for 5 minutes

3. **Error Rate**
   - HTTP 5xx errors per minute
   - Alert if > 10 errors/min

4. **Active Connections**
   - Number of active MySQL connections
   - Alert if > 80% of max_connections

5. **Slow Queries**
   - Queries taking > 1 second
   - Alert if > 5 slow queries in 5 minutes

### 9.5 Alert Configuration

**Alert Channels**:
- Critical: Slack #alerts + PagerDuty
- Warning: Slack #monitoring
- Info: Grafana dashboard annotations

**Alert Rules**:

```yaml
# config/alerting_rules.yml
groups:
  - name: post_migration_monitoring
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.001
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected post-migration"
          description: "Error rate is {{ $value | humanizePercentage }}"

      - alert: SlowDatabaseQueries
        expr: histogram_quantile(0.95, database_query_duration_seconds_bucket) > 0.2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database queries are slow"
          description: "95th percentile query time is {{ $value }}s"

      - alert: ConnectionPoolExhausted
        expr: database_pool_available / database_pool_size < 0.2
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "Only {{ $value | humanizePercentage }} connections available"
```

### 9.6 Success Criteria

**Migration considered successful after**:

- ✅ 24 hours of stable operation
- ✅ All metrics within target ranges
- ✅ No critical incidents
- ✅ Error rate < 0.1%
- ✅ Performance meets or exceeds PostgreSQL baseline
- ✅ Team sign-off

**If success criteria met**:
- Publish success announcement
- Schedule PostgreSQL decommissioning (30 days)
- Archive migration documentation
- Conduct team retrospective

---

## 10. Communication Plan

### 10.1 Pre-Migration Notifications

**Timeline**:

| When | Audience | Channel | Message |
|------|----------|---------|---------|
| T-7 days | All users | Email, Website banner | "Scheduled maintenance on [DATE]" |
| T-3 days | Internal team | Slack, Email | "Migration preparation checklist" |
| T-1 day | All users | Email, Website banner | "Reminder: Maintenance tomorrow" |
| T-4 hours | Internal team | Slack | "Migration starts in 4 hours - team standup" |
| T-30 min | Internal team | Slack, Call | "Final go/no-go decision" |

### 10.2 During Migration Updates

**Update Frequency**: Every 15 minutes
**Channel**: Slack #migration-mysql8

**Status Update Template**:
```
⏰ [TIMESTAMP] - Migration Status Update

📊 Progress: [XX]% complete
🔧 Current Step: [STEP NAME]
⏱️  Elapsed Time: [X] minutes
🎯 Next Checkpoint: [CHECKPOINT NAME] in [X] min

Status: 🟢 On Track / 🟡 Minor Delay / 🔴 Issue Detected

[Additional details if needed]
```

**Example Updates**:
- T+0: "✅ Maintenance mode enabled. Starting backup..."
- T+15: "✅ Backup complete (250 MB). Starting pgloader..."
- T+30: "✅ Data migration complete. Verifying row counts..."
- T+45: "✅ Verification passed. Updating configuration..."
- T+60: "✅ Application restarted. Running smoke tests..."
- T+80: "🎉 Migration complete! Disabling maintenance mode..."

### 10.3 Post-Migration Notifications

**Immediate (T+90 min)**:
```
Subject: ✅ Database Migration Completed Successfully

Dear Team,

The MySQL 8 database migration has been completed successfully.

Migration Summary:
- Start Time: [TIME]
- End Time: [TIME]
- Total Duration: [X] minutes
- Maintenance Mode: [X] minutes
- Data Migrated: 5 tables, [XXXXX] total rows
- Data Verification: ✅ 100% match

Current Status:
- Application: ✅ Running on MySQL 8
- Health Checks: ✅ All passing
- Performance: ✅ Within targets

Next Steps:
- 24-hour intensive monitoring in progress
- Daily monitoring reports for 7 days
- PostgreSQL instance retained for 30 days

Thank you for your patience during the maintenance window.

[YOUR NAME]
Migration Lead
```

**Daily Updates (Days 1-7)**:
- Post daily monitoring report to Slack #migration-mysql8
- Highlight any issues or performance improvements
- Update stakeholders on stability

**Final Report (Day 7)**:
```
Subject: MySQL 8 Migration - Final Report

The MySQL 8 migration is complete and stable after 7 days of monitoring.

Final Metrics:
- Uptime: [XX.XX]%
- Avg Response Time: [XX] ms
- Error Rate: [X.XX]%
- Performance vs Baseline: [+/-X%]

Incidents: [None / X minor incidents, all resolved]

Recommendation: ✅ Decommission PostgreSQL instance on [DATE]

Full report: docs/migration/final-migration-report.md
```

### 10.4 Escalation Procedure

**Level 1: Warning Issues**
- Contact: Migration Lead
- Channel: Slack #migration-mysql8
- Response Time: 5 minutes

**Level 2: Critical Issues**
- Contact: DevOps Manager + CTO
- Channel: Phone + Slack
- Response Time: Immediate

**Level 3: Rollback Decision**
- Contact: CTO + Executive Team
- Channel: Conference Call
- Decision Time: 10 minutes maximum

### 10.5 Communication Templates

**Rollback Announcement**:
```
Subject: ⚠️  Migration Rollback Initiated

The MySQL 8 migration is being rolled back due to [REASON].

Actions Taken:
- Maintenance mode remains active
- Rollback script executing
- Application will be restored on PostgreSQL

Estimated Resolution: [X] minutes

We will provide updates every 5 minutes until resolution.

[YOUR NAME]
Migration Lead
```

**Rollback Completion**:
```
Subject: ✅ Rollback Complete - Service Restored

The migration rollback has been completed successfully.

Current Status:
- Application: ✅ Running on PostgreSQL
- Data: ✅ No data loss
- Functionality: ✅ All features operational
- Maintenance Mode: Disabled

Next Steps:
- Root cause analysis in progress
- New migration date to be announced

Thank you for your patience.

[YOUR NAME]
Migration Lead
```

---

## 11. Appendix

### 11.1 Environment Variables Reference

**Required Environment Variables**:

```bash
# MySQL Connection
export DB_HOST=mysql-prod-01.example.com
export DB_PORT=3306
export DB_NAME=reline_production
export DB_USERNAME=reline_app
export DB_PASSWORD=[SECURE_PASSWORD]

# SSL/TLS Configuration
export DB_SSL_CA=/etc/mysql/certs/ca-cert.pem
export DB_SSL_KEY=/etc/mysql/certs/client-key.pem
export DB_SSL_CERT=/etc/mysql/certs/client-cert.pem

# Rails Configuration
export RAILS_ENV=production
export RAILS_MAX_THREADS=10

# Backup Configuration (for reference)
export PG_HOST=postgresql-prod-01.example.com
export PG_PORT=5432
export PG_DATABASE=reline_production
export PG_USER=postgres
export PG_PASSWORD=[SECURE_PASSWORD]
```

### 11.2 Database Credentials

**DO NOT include actual credentials in this document.**

Credentials stored in:
- Production: AWS Secrets Manager / HashiCorp Vault
- Staging: Environment variables on server
- Development: `.env` file (gitignored)

**Access Instructions**:
1. For MySQL production credentials: Contact DevOps team
2. For emergency access: Use AWS Secrets Manager console
3. For credential rotation: Follow security team procedures

### 11.3 Useful Commands

**MySQL Connection**:
```bash
# Connect to MySQL
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D reline_production

# Test SSL connection
mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD \
  --ssl-ca=$DB_SSL_CA \
  --ssl-key=$DB_SSL_KEY \
  --ssl-cert=$DB_SSL_CERT \
  -e "SHOW STATUS LIKE 'Ssl_cipher';"
```

**Database Operations**:
```sql
-- Check database size
SELECT TABLE_NAME,
       ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'reline_production'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- Check row counts
SELECT 'alarm_contents' AS table_name, COUNT(*) AS row_count FROM alarm_contents
UNION ALL SELECT 'contents', COUNT(*) FROM contents
UNION ALL SELECT 'feedbacks', COUNT(*) FROM feedbacks
UNION ALL SELECT 'line_groups', COUNT(*) FROM line_groups
UNION ALL SELECT 'operators', COUNT(*) FROM operators;

-- Check active connections
SHOW FULL PROCESSLIST;

-- Check slow queries
SELECT * FROM mysql.slow_log
ORDER BY query_time DESC
LIMIT 10;

-- Optimize tables (optional, post-migration)
OPTIMIZE TABLE alarm_contents, contents, feedbacks, line_groups, operators;
```

**Rails Commands**:
```bash
# Check database adapter
RAILS_ENV=production bundle exec rails runner \
  "puts ActiveRecord::Base.connection.adapter_name"

# Check database version
RAILS_ENV=production bundle exec rails runner \
  "puts ActiveRecord::Base.connection.select_value('SELECT VERSION()')"

# Run migrations
RAILS_ENV=production bundle exec rails db:migrate

# Check migration status
RAILS_ENV=production bundle exec rails db:version

# Open Rails console (read-only)
RAILS_ENV=production bundle exec rails console --sandbox
```

**Monitoring Commands**:
```bash
# Check Prometheus metrics
curl -s http://localhost:3000/metrics | grep database

# Query Prometheus API
curl -s 'http://prometheus:9090/api/v1/query?query=database_pool_available' | jq .

# Check application logs
tail -f /var/log/reline/production.log

# Check system resources
htop
iostat -x 1
```

### 11.4 Related Documentation

**Design Documents**:
- Design Document: `docs/designs/mysql8-unification.md`
- Task Plan: `docs/plans/mysql8-unification-tasks.md`

**Infrastructure**:
- MySQL 8 Setup: `docs/infrastructure/mysql8-setup.md`
- SSL Configuration: `docs/infrastructure/ssl-setup.md`
- Staging Environment: `docs/infrastructure/staging-environment.md`

**Migration**:
- Staging Migration Report: `docs/migration/staging-migration-report.md`
- pgloader Setup: `docs/migration/pgloader-setup.md`
- Pre-Deployment Verification: `docs/migration/pre-deployment-verification.md`

**Performance**:
- MySQL 8 Benchmarks: `docs/performance/mysql8-benchmarks.md`
- PostgreSQL Baseline: `docs/performance/postgresql-baseline.md`

**Observability**:
- Grafana Setup: `docs/observability/grafana-setup.md`
- Alerting Configuration: `docs/observability/alerting.md`

### 11.5 Emergency Contacts

| Role | Name | Phone | Slack | Email |
|------|------|-------|-------|-------|
| Migration Lead | [FILL IN] | [FILL IN] | @[username] | [email] |
| DevOps Manager | [FILL IN] | [FILL IN] | @[username] | [email] |
| CTO | [FILL IN] | [FILL IN] | @[username] | [email] |
| Database Expert | [FILL IN] | [FILL IN] | @[username] | [email] |
| On-Call Engineer | [FILL IN] | [FILL IN] | @[username] | [email] |

**Emergency Escalation**:
1. Migration team member notices issue
2. Notify Migration Lead immediately (Slack + phone)
3. Migration Lead makes go/rollback decision
4. If rollback: Notify DevOps Manager + CTO
5. If critical incident: Initiate conference call

### 11.6 Troubleshooting Guide

#### Issue: pgloader fails with "connection refused"

**Symptoms**: pgloader cannot connect to MySQL
**Cause**: Network/firewall issue or MySQL not running
**Solution**:
1. Verify MySQL is running: `systemctl status mysql`
2. Test connection: `mysql -h $MYSQL_HOST -u $MYSQL_USER -p`
3. Check firewall rules: `sudo iptables -L | grep 3306`
4. Verify security groups (if on AWS)

#### Issue: Row count mismatch

**Symptoms**: Verification script reports different row counts
**Cause**: Migration incomplete or data inconsistency
**Solution**:
1. Check pgloader output for errors
2. Verify pgloader completed all tables
3. Re-run migration for affected tables
4. If mismatch > 0.1%: ROLLBACK IMMEDIATELY

#### Issue: Rails cannot connect to MySQL

**Symptoms**: `ActiveRecord::ConnectionNotEstablished` error
**Cause**: Wrong credentials, SSL issue, or network problem
**Solution**:
1. Verify environment variables: `env | grep DB_`
2. Test connection: `mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD`
3. Check SSL certificates exist: `ls -l /etc/mysql/certs/`
4. Verify database.yml configuration
5. Check Rails logs: `tail -f log/production.log`

#### Issue: Application won't start

**Symptoms**: systemctl reports "failed"
**Cause**: Configuration error, port conflict, or dependencies
**Solution**:
1. Check logs: `journalctl -u reline-app -n 100`
2. Verify port 3000 available: `lsof -i :3000`
3. Test bundle: `bundle exec rails --version`
4. Check file permissions
5. Try starting manually: `bundle exec rails s -e production`

#### Issue: Slow queries after migration

**Symptoms**: Response time > 500ms
**Cause**: Missing indexes or poor query plans
**Solution**:
1. Identify slow queries: `SHOW FULL PROCESSLIST;`
2. Check query plans: `EXPLAIN SELECT ...`
3. Verify indexes exist: `SHOW INDEXES FROM table_name;`
4. Re-run migrations if indexes missing
5. Consider adding composite indexes

### 11.7 Lessons Learned (Post-Migration)

**To be filled after migration completion.**

**What Went Well**:
- [TO BE COMPLETED]

**What Went Wrong**:
- [TO BE COMPLETED]

**Improvements for Next Time**:
- [TO BE COMPLETED]

**Unexpected Issues**:
- [TO BE COMPLETED]

### 11.8 Sign-Off

**Pre-Migration Approval**:

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Migration Lead | [FILL IN] | __________ | ____ |
| Database Engineer | [FILL IN] | __________ | ____ |
| DevOps Manager | [FILL IN] | __________ | ____ |
| CTO | [FILL IN] | __________ | ____ |

**Post-Migration Verification**:

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Migration Lead | [FILL IN] | __________ | ____ |
| QA Engineer | [FILL IN] | __________ | ____ |
| DevOps Manager | [FILL IN] | __________ | ____ |

---

## Document Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-24 | AI Agent | Initial runbook creation based on design doc and task plan |

---

**END OF PRODUCTION MIGRATION RUNBOOK**

**This runbook is a living document. Update based on staging migration experience and team feedback.**

**Last Updated**: 2025-11-24
**Next Review**: After staging migration (before production migration)
**Document Owner**: [MIGRATION LEAD NAME]
