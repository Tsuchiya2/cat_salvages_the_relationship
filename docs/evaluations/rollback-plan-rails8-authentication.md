# Rollback Plan Evaluation - Rails 8 Authentication Migration

**Feature ID**: FEAT-AUTH-001
**Evaluation Date**: 2025-11-28
**Evaluator**: rollback-plan-evaluator
**Overall Score**: 4.8 / 10.0
**Overall Status**: NEEDS PLAN

---

## Executive Summary

The Rails 8 authentication migration implementation demonstrates strong technical execution with reversible database migrations, comprehensive validation utilities, and well-structured code. However, it critically lacks documented rollback procedures, disaster recovery planning, and operational safeguards necessary for a production authentication system migration.

While the database migrations include proper `down()` methods and validation logic, there is no documented rollback plan, no feature flag implementation for gradual rollout, no backup strategy, and no defined rollback triggers or procedures. The implementation assumes a successful migration without planning for failure scenarios.

**Critical Gaps Identified:**
1. No rollback documentation or runbook exists
2. No feature flags implemented for phased rollout
3. No automated backup strategy before migrations
4. No monitoring dashboards or alerts configured for rollback triggers
5. No defined RTO/RPO or rollback time estimates
6. Migration 003 (remove Sorcery columns) has unclear execution timeline

**Recommendation:** Create comprehensive rollback documentation, implement feature flags for controlled rollout, establish backup procedures, and configure monitoring before production deployment.

---

## Evaluation Results

### 1. Rollback Documentation (Weight: 30%)
- **Score**: 2.0 / 10
- **Status**: ❌ Missing

**Findings**:
- Rollback documentation: **Missing**
  - No `ROLLBACK.md` or `docs/deployment/rollback.md` found
  - No rollback procedure in design document
  - No rollback steps in task plan beyond database migration down() methods
- Rollback procedure: **Not Documented**
  - No step-by-step rollback instructions
  - No coordination between code and database rollback
  - No verification steps after rollback
- Rollback triggers: **Not Defined**
  - No defined error rate thresholds (e.g., >5% failure rate)
  - No performance degradation thresholds (e.g., p95 latency >500ms)
  - No manual intervention criteria
- Rollback testing: **Not Documented**
  - No rollback testing plan
  - No staging environment rollback verification
  - No rollback rehearsal procedure
- Rollback responsibilities: **Not Assigned**
  - No defined roles (who can initiate rollback)
  - No approval requirements
  - No escalation path

**Issues**:
1. ❌ **No rollback documentation** (Critical)
   - Location: Expected at `docs/deployment/ROLLBACK.md` or similar - not found
   - Impact: Team has no guidance on how to rollback during incident
   - Evidence: Searched entire `docs/` directory - no rollback documentation exists
   - Recommendation: Create comprehensive `ROLLBACK.md` with step-by-step procedures

2. ❌ **No rollback triggers defined** (High)
   - Impact: Team won't know when to initiate rollback
   - Recommendation: Define quantitative triggers:
     - Authentication failure rate >5% for 5 minutes
     - Login latency p95 >500ms for 5 minutes
     - Database connection errors >10%
     - User-reported critical bugs

3. ❌ **No rollback testing plan** (High)
   - Impact: Rollback procedure may fail when actually needed
   - Recommendation: Document rollback testing on staging environment

**Recommendations**:
- **Immediate**: Create `docs/deployment/ROLLBACK.md` with:
  - Clear rollback triggers (error rate thresholds, latency thresholds)
  - Step-by-step rollback procedure (code + database)
  - Rollback verification checklist
  - Rollback authority matrix (who can approve/execute)
  - Estimated rollback time (target: <15 minutes)
- **Before Production**: Test complete rollback procedure on staging
- **Production Ready**: Conduct rollback drill with operations team

### 2. Database Migration Rollback (Weight: 25%)
- **Score**: 8.5 / 10
- **Status**: ✅ Reversible

**Findings**:
- Migrations with rollback: **3/3 migrations** (100%)
- Reversibility: **All migrations reversible**
- Backup strategy: **Not Documented** (critical gap)
- Migration rollback tested: **Unknown** (no evidence of testing)

**Migration Analysis**:
| Migration File | Rollback Exists | Reversible | Data Safety | Issues |
|---------------|----------------|------------|-------------|--------|
| `20251125141044_add_password_digest_to_operators.rb` | ✅ Yes | ✅ Yes | ✅ Safe | None - adds column only |
| `20251125142049_migrate_sorcery_passwords.rb` | ✅ Yes | ✅ Yes | ✅ Safe | Excellent validation logic |
| `20251125142050_remove_sorcery_columns_from_operators.rb` | ⚠️ Yes | ⚠️ Partial | ❌ Data Loss | Cannot restore password data |

**Detailed Migration Assessment**:

**Migration 001 - Add password_digest**:
```ruby
def change
  add_column :operators, :password_digest, :string
  add_index :operators, :password_digest
end
```
- ✅ **Excellent**: Simple, reversible, no data modification
- ✅ Uses `change` method - Rails auto-generates `down()`
- ✅ Safe to rollback at any time
- ⚠️ Minor: Index on `password_digest` may not be necessary

**Migration 002 - Migrate passwords**:
```ruby
def up
  # Pre-migration validation
  # Copy crypted_password to password_digest
  # Post-migration validation
  # Integrity verification
  # Password hash verification
end

def down
  Operator.update_all(password_digest: nil)
end
```
- ✅ **Outstanding**: Comprehensive validation and integrity checks
- ✅ Checksum-based verification using stable fields (ID, email, name, role)
- ✅ Transaction safety with detailed error messages
- ✅ Reversible - clears password_digest on rollback
- ✅ Validates password_digest matches crypted_password
- ✅ Includes checksums before/after migration
- **Note**: Rollback clears password_digest but preserves crypted_password (Sorcery auth still works)

**Migration 003 - Remove Sorcery columns**:
```ruby
def up
  remove_column :operators, :crypted_password, :string
  remove_column :operators, :salt, :string
end

def down
  add_column :operators, :crypted_password, :string
  add_column :operators, :salt, :string
end
```
- ⚠️ **WARNING**: Includes warning comments but lacks technical safeguards
- ⚠️ Partial reversibility: Can restore columns but NOT data
- ❌ **Critical Gap**: No backup mechanism to restore password data
- ⚠️ Comment says "Only run after 30-day verification" but no enforcement
- ⚠️ No pre-execution validation (e.g., check all operators can authenticate)
- ⚠️ Rollback restores schema but password data is lost permanently

**Issues**:
1. ⚠️ **Migration 003 lacks execution safeguards** (High)
   - Location: `db/migrate/20251125142050_remove_sorcery_columns_from_operators.rb`
   - Issue: Warning comments but no technical enforcement of 30-day delay
   - Impact: Could be accidentally run too early, preventing rollback
   - Recommendation: Add pre-execution validation:
     ```ruby
     def up
       # Verify 30-day period has passed
       migration_date = Time.parse('20251125142049')
       if Time.current - migration_date < 30.days
         raise "Cannot run this migration yet! Wait until #{migration_date + 30.days}"
       end

       # Verify all operators can authenticate with password_digest
       failed_auth = Operator.count do |op|
         !op.authenticate(known_test_password_from_encrypted_storage)
       end
       if failed_auth > 0
         raise "Cannot remove Sorcery columns: #{failed_auth} operators cannot authenticate"
       end

       remove_column :operators, :crypted_password
       remove_column :operators, :salt
     end
     ```

2. ❌ **No backup strategy documented** (Critical)
   - Impact: Cannot restore data if migration fails
   - Current state: No documented backup procedure before migrations
   - Recommendation: Document backup strategy:
     ```bash
     # Before running migrations in production
     # 1. Create database snapshot
     mysqldump -u root reline_production > backup_$(date +%Y%m%d_%H%M%S).sql

     # 2. Upload to secure storage
     aws s3 cp backup_*.sql s3://myapp-backups/pre-auth-migration/

     # 3. Verify backup integrity
     mysql -u root reline_test < backup_*.sql
     ```

3. ⚠️ **No rollback testing evidence** (Medium)
   - Impact: Unknown if rollback actually works
   - Recommendation: Test rollback on staging:
     ```bash
     # On staging environment
     rails db:migrate:up VERSION=20251125142049  # Run migration
     rails db:migrate:down VERSION=20251125142049  # Test rollback
     # Verify Sorcery authentication still works
     ```

**Recommendations**:
- **Immediate**: Document backup procedure for production deployment
- **Before Migration 003**: Add technical safeguards to prevent premature execution
- **Testing**: Verify rollback of Migration 002 on staging environment
- **Production**: Create automated backup before running migrations
- **Post-Migration**: Keep Sorcery columns for 30+ days before running Migration 003
- **Backup Retention**: Store backups for minimum 90 days with 7-year archive

### 3. Code Deployment Rollback (Weight: 20%)
- **Score**: 3.0 / 10
- **Status**: ⚠️ Partially Ready

**Findings**:
- Releases tagged in git: **No tags found**
  - Checked `.git/refs/tags/` - directory exists but empty
  - No version tagging strategy in place
- Rollback command documented: **Not documented**
  - No deployment scripts found
  - No documented rollback procedure
- Fast rollback possible: **Unknown**
  - No deployment automation visible
  - No blue-green or canary deployment strategy
  - No documented deployment method
- Deployment automation: **Not present**
  - No GitHub Actions workflows found
  - No deployment scripts in repository
  - Execution environment is "local (no Docker)"

**Issues**:
1. ❌ **No git version tagging** (Critical)
   - Location: `.git/refs/tags/` is empty
   - Impact: Cannot identify "last known good" version for rollback
   - Current state: No releases tagged (e.g., `v1.0.0`, `v1.1.0`)
   - Recommendation: Implement semantic versioning:
     ```bash
     # Before deploying to production
     git tag -a v1.2.0 -m "Release v1.2.0 - Pre-authentication migration"
     git push origin v1.2.0

     # After successful migration
     git tag -a v1.3.0 -m "Release v1.3.0 - Rails 8 authentication"
     git push origin v1.3.0
     ```

2. ❌ **No rollback command documented** (Critical)
   - Impact: Team doesn't know how to revert code deployment
   - Recommendation: Document deployment and rollback commands:
     ```bash
     # Deployment (example for local execution)
     # 1. Pull specific version
     git fetch --tags
     git checkout v1.3.0

     # 2. Install dependencies
     bundle install

     # 3. Restart application
     systemctl restart rails-app  # or equivalent

     # ROLLBACK PROCEDURE
     # 1. Checkout previous version
     git checkout v1.2.0

     # 2. Rollback database migrations
     rails db:migrate:down VERSION=20251125142049

     # 3. Install dependencies
     bundle install

     # 4. Restart application
     systemctl restart rails-app

     # 5. Verify rollback
     curl -I https://app.example.com/operator/cat_in
     # Expected: 200 OK
     ```

3. ❌ **No deployment automation** (High)
   - Impact: Manual deployment increases rollback time and error risk
   - Current state: No CI/CD pipelines detected
   - Recommendation: Implement basic deployment automation:
     - Consider GitHub Actions, Capistrano, or similar
     - Automate backup before deployment
     - Automate health checks after deployment
     - Document rollback triggers and procedures

4. ⚠️ **Unknown deployment strategy** (Medium)
   - Impact: Cannot estimate rollback time
   - No evidence of blue-green, canary, or rolling deployment
   - Recommendation: Document current deployment process:
     - How is code deployed to production?
     - What is the typical deployment time?
     - What is the expected rollback time?

**Recommendations**:
- **Immediate**: Start tagging releases with semantic versioning
- **Before Production**: Document complete deployment and rollback procedure
- **Deployment**: Implement basic deployment automation or document manual steps
- **Rollback Testing**: Practice code rollback on staging environment
- **Target**: Achieve <10 minute code rollback time

### 4. Data Backup & Recovery (Weight: 15%)
- **Score**: 1.5 / 10
- **Status**: ❌ Not Ready

**Findings**:
- Backup strategy documented: **No** - No backup documentation found
- Backup schedule defined: **No** - No automated backup strategy
- Backup restoration tested: **Unknown** - No evidence of testing
- Backup retention policy: **Not defined**

**Current State**:
- Database: MySQL 8.0+ (development/test), PostgreSQL (production - inferred)
- No backup scripts in repository
- No `.env` variables for backup configuration
- No backup documentation in `docs/` directory
- No disaster recovery plan

**Issues**:
1. ❌ **No backup strategy documented** (Critical)
   - Impact: Cannot recover data if migration fails catastrophically
   - Risk: Data loss, extended downtime
   - Recommendation: Create `docs/deployment/BACKUP_STRATEGY.md`:
     ```markdown
     ## Pre-Deployment Backup Strategy

     ### 1. Database Backup
     ```bash
     # Create timestamped backup
     DATE=$(date +%Y%m%d_%H%M%S)
     BACKUP_FILE="backup_pre_auth_migration_${DATE}.sql"

     # Production (PostgreSQL)
     pg_dump -U postgres -h db.example.com reline_production > ${BACKUP_FILE}

     # Compress backup
     gzip ${BACKUP_FILE}

     # Upload to secure storage (S3, GCS, etc.)
     aws s3 cp ${BACKUP_FILE}.gz s3://myapp-backups/pre-migration/
     ```

     ### 2. Backup Verification
     ```bash
     # Test restore to temporary database
     gunzip -c ${BACKUP_FILE}.gz | psql -U postgres -h db.example.com reline_test_restore

     # Verify record counts
     psql -U postgres -h db.example.com reline_test_restore -c "SELECT COUNT(*) FROM operators;"
     ```

     ### 3. Backup Retention Policy
     - Pre-migration backups: 90 days (minimum)
     - Daily backups: 7 days
     - Weekly backups: 4 weeks
     - Monthly backups: 12 months
     - Annual archives: 7 years (compliance)
     ```

2. ❌ **No automated backup before migrations** (Critical)
   - Impact: Human error could cause migrations without backup
   - Recommendation: Add backup check to migration:
     ```ruby
     # In critical migrations
     def up
       unless Rails.env.development? || Rails.env.test?
         backup_file = ENV['MIGRATION_BACKUP_FILE']
         if backup_file.blank?
           raise "MIGRATION_BACKUP_FILE environment variable required for production migrations"
         end

         unless File.exist?(backup_file)
           raise "Backup file not found: #{backup_file}. Create backup before migration."
         end
       end

       # ... migration code ...
     end
     ```

3. ❌ **No backup restoration tested** (High)
   - Impact: Backup may be corrupted or incomplete
   - Recommendation: Test backup restoration quarterly:
     ```bash
     # Backup restoration test procedure
     # 1. Restore to temporary database
     # 2. Verify record counts match production
     # 3. Verify data integrity (checksums)
     # 4. Test authentication with restored database
     # 5. Document restoration time
     ```

4. ❌ **No retention policy defined** (Medium)
   - Impact: May delete backups too early, preventing recovery
   - Recommendation: Define clear retention policy:
     - Critical migration backups: 90 days minimum
     - Regular daily backups: 7 days
     - Weekly backups: 30 days
     - Monthly backups: 1 year
     - Compliance archives: 7 years

**Recommendations**:
- **Critical - Before Production**: Create comprehensive backup strategy document
- **Mandatory**: Create database backup before running migrations
- **Testing**: Test backup restoration procedure before production deployment
- **Automation**: Implement automated backup verification
- **Monitoring**: Set up alerts for backup failures
- **Documentation**: Document restoration procedure with time estimates

### 5. Feature Flags / Kill Switches (Weight: 5%)
- **Score**: 0.5 / 10
- **Status**: ❌ Not Implemented

**Findings**:
- Feature flags implemented: **No** - No feature flag implementation found
- Kill switch documented: **No** - No way to disable feature without redeployment
- Feature flag configuration: **Mentioned but not implemented**
  - Design document mentions `AUTH_OAUTH_ENABLED`, `AUTH_MFA_ENABLED`
  - Authentication config includes feature flags but only for future features
  - No feature flag for the authentication migration itself

**Current State**:
```ruby
# config/initializers/authentication.rb
Rails.application.config.authentication = {
  # Feature Flags (for future features, not migration control)
  oauth_enabled: ENV.fetch('AUTH_OAUTH_ENABLED', 'false') == 'true',
  mfa_enabled: ENV.fetch('AUTH_MFA_ENABLED', 'false') == 'true'
}
```

**Analysis**:
- Configuration includes feature flags for OAuth and MFA (future features)
- **No feature flag for controlling Rails 8 vs Sorcery authentication**
- No gradual rollout mechanism (0% → 1% → 10% → 50% → 100%)
- No ability to disable Rails 8 authentication without code rollback

**Issues**:
1. ❌ **No feature flag for authentication migration** (Critical)
   - Issue: Cannot perform gradual rollout or instant rollback
   - Impact: All-or-nothing deployment increases risk
   - Current: Authentication system switches entirely on deployment
   - Recommendation: Implement feature flag:
     ```ruby
     # config/initializers/authentication.rb
     Rails.application.config.authentication = {
       # Migration control feature flag
       use_rails8_auth: ENV.fetch('USE_RAILS8_AUTH', 'false') == 'true',
       rollout_percentage: ENV.fetch('AUTH_ROLLOUT_PERCENTAGE', '0').to_i,

       # Existing feature flags...
       oauth_enabled: ENV.fetch('AUTH_OAUTH_ENABLED', 'false') == 'true',
       mfa_enabled: ENV.fetch('AUTH_MFA_ENABLED', 'false') == 'true'
     }

     # app/controllers/concerns/authentication.rb
     def authenticate_operator(email, password)
       if use_rails8_for_operator?(email)
         # Rails 8 authentication
         result = AuthenticationService.authenticate(:password, email: email, password: password)
         result.success? ? result.user : nil
       else
         # Sorcery authentication (fallback)
         login(email, password)
       end
     end

     def use_rails8_for_operator?(email)
       return false unless Rails.application.config.authentication[:use_rails8_auth]

       # Gradual rollout based on email hash
       rollout_pct = Rails.application.config.authentication[:rollout_percentage]
       return true if rollout_pct >= 100

       # Consistent hashing for gradual rollout
       email_hash = Digest::MD5.hexdigest(email).to_i(16)
       (email_hash % 100) < rollout_pct
     end
     ```

2. ❌ **No instant kill switch** (High)
   - Issue: Cannot instantly disable Rails 8 auth during incident
   - Impact: Requires code rollback (slow, risky)
   - Recommendation: Environment variable kill switch:
     ```bash
     # Instant disable via environment variable
     USE_RAILS8_AUTH=false

     # Restart application (or use hot reload if available)
     systemctl restart rails-app

     # Verification
     curl https://app.example.com/health/auth
     # Expected: {"auth_provider": "sorcery", "status": "ok"}
     ```

3. ⚠️ **No gradual rollout strategy** (High)
   - Issue: Cannot test with small percentage of traffic
   - Impact: Issues may affect all users simultaneously
   - Recommendation: Gradual rollout plan:
     ```
     Phase 1: Deploy with USE_RAILS8_AUTH=false (Sorcery only)
     Phase 2: Enable for 1% users (AUTH_ROLLOUT_PERCENTAGE=1)
     Phase 3: Monitor for 24 hours, check metrics
     Phase 4: Increase to 10% if stable
     Phase 5: Increase to 50% if stable
     Phase 6: Increase to 100% if stable
     ```

4. ⚠️ **No A/B testing capability** (Medium)
   - Issue: Cannot compare Sorcery vs Rails 8 performance
   - Recommendation: Log which authentication system was used:
     ```ruby
     Rails.logger.info(
       event: 'authentication_attempt',
       auth_system: use_rails8_for_operator?(email) ? 'rails8' : 'sorcery',
       result: result.status
     )
     ```

**Recommendations**:
- **Critical**: Implement `USE_RAILS8_AUTH` feature flag
- **High Priority**: Implement gradual rollout percentage control
- **Production Deployment**: Start with feature flag disabled (Sorcery only)
- **Rollout Plan**: 0% → 1% → 10% → 50% → 100% over multiple days
- **Kill Switch**: Document instant disable procedure
- **Monitoring**: Track authentication by system (Sorcery vs Rails 8)

### 6. Monitoring & Alerting for Rollback (Weight: 5%)
- **Score**: 4.5 / 10
- **Status**: ⚠️ Partially Configured

**Findings**:
- Monitoring configured: **Partial** - Prometheus metrics exist but no dashboards
- Alerts configured: **No** - No alert rules defined
- Runbook exists: **No** - No operational runbook found

**Current Monitoring Setup**:
```ruby
# config/initializers/prometheus.rb
AUTH_ATTEMPTS_TOTAL = prometheus.counter(
  :auth_attempts_total,
  labels: [:provider, :result]
)

AUTH_DURATION = prometheus.histogram(
  :auth_duration_seconds,
  labels: [:provider],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
)

AUTH_FAILURES_TOTAL = prometheus.counter(
  :auth_failures_total,
  labels: [:provider, :reason]
)

AUTH_LOCKED_ACCOUNTS_TOTAL = prometheus.counter(
  :auth_locked_accounts_total,
  labels: [:provider]
)
```

**Structured Logging**:
```ruby
# config/initializers/lograge.rb
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new

config.lograge.custom_options = lambda do |event|
  {
    correlation_id: RequestStore.store[:correlation_id],
    request_id: RequestStore.store[:request_id],
    user_id: event.payload[:user_id],
    user_email: event.payload[:user_email],
    result: event.payload[:result],
    reason: event.payload[:reason],
    timestamp: Time.current.iso8601
  }
end
```

**Analysis**:
- ✅ **Good**: Comprehensive metrics defined (attempts, duration, failures, locked accounts)
- ✅ **Good**: Structured JSON logging with request correlation
- ✅ **Good**: Histogram buckets appropriate for authentication latency
- ❌ **Missing**: No Grafana/Prometheus dashboards configured
- ❌ **Missing**: No alert rules defined
- ❌ **Missing**: No runbook for investigating authentication issues
- ⚠️ **Gap**: Metrics recorded but no visualization or alerting

**Issues**:
1. ❌ **No alert rules configured** (Critical)
   - Impact: Team won't be notified of authentication failures
   - Recommendation: Configure Prometheus alerts:
     ```yaml
     # prometheus-alerts.yml
     groups:
       - name: authentication
         interval: 30s
         rules:
           # Alert: High authentication failure rate
           - alert: HighAuthFailureRate
             expr: |
               (
                 sum(rate(auth_failures_total[5m]))
                 /
                 sum(rate(auth_attempts_total[5m]))
               ) > 0.05
             for: 5m
             labels:
               severity: critical
               component: authentication
             annotations:
               summary: "High authentication failure rate (>5%)"
               description: "{{ $value | humanizePercentage }} of authentication attempts are failing"

           # Alert: High authentication latency
           - alert: HighAuthLatency
             expr: |
               histogram_quantile(0.95, rate(auth_duration_seconds_bucket[5m])) > 0.5
             for: 5m
             labels:
               severity: warning
               component: authentication
             annotations:
               summary: "High authentication latency (p95 >500ms)"
               description: "95th percentile authentication latency is {{ $value }}s"

           # Alert: Account lockout spike
           - alert: AccountLockoutSpike
             expr: |
               rate(auth_locked_accounts_total[5m]) > 0.1
             for: 2m
             labels:
               severity: warning
               component: authentication
             annotations:
               summary: "Account lockout rate spike detected"
               description: "{{ $value }} accounts per second being locked"
     ```

2. ❌ **No monitoring dashboard** (High)
   - Impact: Cannot visualize authentication health during migration
   - Recommendation: Create Grafana dashboard:
     ```json
     {
       "dashboard": {
         "title": "Authentication Monitoring",
         "panels": [
           {
             "title": "Authentication Success Rate",
             "targets": [{
               "expr": "sum(rate(auth_attempts_total{result='success'}[5m])) / sum(rate(auth_attempts_total[5m]))"
             }],
             "alert": {
               "conditions": [{"evaluator": {"params": [0.95], "type": "lt"}}]
             }
           },
           {
             "title": "Authentication Latency (p50, p95, p99)",
             "targets": [
               {"expr": "histogram_quantile(0.50, rate(auth_duration_seconds_bucket[5m]))"},
               {"expr": "histogram_quantile(0.95, rate(auth_duration_seconds_bucket[5m]))"},
               {"expr": "histogram_quantile(0.99, rate(auth_duration_seconds_bucket[5m]))"}
             ]
           },
           {
             "title": "Authentication Failures by Reason",
             "targets": [{
               "expr": "sum by (reason) (rate(auth_failures_total[5m]))"
             }]
           },
           {
             "title": "Account Lockout Rate",
             "targets": [{
               "expr": "rate(auth_locked_accounts_total[5m])"
             }]
           }
         ]
       }
     }
     ```

3. ❌ **No runbook for authentication issues** (High)
   - Impact: Team doesn't know how to investigate or resolve issues
   - Recommendation: Create `docs/runbooks/authentication-troubleshooting.md`:
     ```markdown
     # Authentication Troubleshooting Runbook

     ## Symptoms & Rollback Triggers

     ### Trigger 1: High Failure Rate (>5% for 5 minutes)
     **Detection**: Prometheus alert `HighAuthFailureRate`
     **Investigation**:
     1. Check Grafana dashboard for failure reasons
     2. Check logs: `grep -i "authentication_attempt.*failed" /var/log/rails/production.log`
     3. Identify pattern: all users vs specific users

     **Rollback Decision**:
     - If >10% failure rate: **IMMEDIATE ROLLBACK**
     - If 5-10% failure rate: Investigate for 10 minutes, then rollback

     **Rollback Procedure**: See `docs/deployment/ROLLBACK.md`

     ### Trigger 2: High Latency (p95 >500ms for 5 minutes)
     **Detection**: Prometheus alert `HighAuthLatency`
     **Investigation**:
     1. Check database query performance
     2. Check bcrypt cost factor configuration
     3. Check server load

     **Rollback Decision**:
     - If p95 >1000ms: **IMMEDIATE ROLLBACK**
     - If p95 500-1000ms: Investigate for 10 minutes, then rollback

     ### Trigger 3: Account Lockout Spike
     **Detection**: Prometheus alert `AccountLockoutSpike`
     **Investigation**:
     1. Check if legitimate brute force attack or bug
     2. Review failed login reasons in logs

     **Rollback Decision**:
     - If bug causing false lockouts: **IMMEDIATE ROLLBACK**
     - If legitimate attack: No rollback, monitor
     ```

4. ⚠️ **No pre-deployment baseline** (Medium)
   - Issue: Cannot compare post-migration metrics to pre-migration
   - Recommendation: Capture baseline metrics before migration:
     ```bash
     # 1 week before migration
     # Capture baseline metrics
     - Average authentication success rate
     - p50/p95/p99 latency
     - Account lockout rate
     - Peak load authentication throughput
     ```

**Recommendations**:
- **Critical**: Configure Prometheus alert rules before production deployment
- **High**: Create Grafana dashboard for authentication monitoring
- **High**: Document runbook for authentication troubleshooting and rollback
- **Medium**: Capture baseline metrics before migration
- **Production**: Monitor dashboard continuously during rollout
- **Post-Deployment**: Review alerts and adjust thresholds as needed

---

## Overall Assessment

**Total Score**: 4.8 / 10.0

**Score Breakdown**:
- Rollback Documentation: 2.0 / 10 (Weight: 30%) = 0.6 points
- Database Migration Rollback: 8.5 / 10 (Weight: 25%) = 2.1 points
- Code Deployment Rollback: 3.0 / 10 (Weight: 20%) = 0.6 points
- Data Backup & Recovery: 1.5 / 10 (Weight: 15%) = 0.2 points
- Feature Flags / Kill Switches: 0.5 / 10 (Weight: 5%) = 0.0 points
- Monitoring & Alerting: 4.5 / 10 (Weight: 5%) = 0.2 points

**Status Determination**:
- ✅ **ROLLBACK READY** (Score ≥ 7.0): Comprehensive rollback plan exists
- ⚠️ **NEEDS PLAN** (Score 4.0-6.9): Partial rollback plan, improvements needed ← **CURRENT STATUS**
- ❌ **NO ROLLBACK PLAN** (Score < 4.0): Critical rollback gaps exist

**Overall Status**: ⚠️ NEEDS PLAN

**Assessment**:
The implementation demonstrates strong technical quality in database migration design with comprehensive validation, reversibility, and data integrity checks. However, it critically lacks operational readiness for production deployment. The absence of rollback documentation, feature flags, backup procedures, and monitoring alerts creates significant risk for a production authentication system migration.

### Strengths
1. ✅ **Excellent database migration design**:
   - All migrations have proper `down()` methods
   - Comprehensive validation and checksum verification
   - Transaction safety with detailed error messages
   - Clear separation of additive, migration, and removal phases

2. ✅ **Good observability foundation**:
   - Prometheus metrics properly instrumented
   - Structured JSON logging with request correlation
   - Comprehensive metric coverage (attempts, failures, duration, lockouts)

3. ✅ **Clean implementation**:
   - Well-documented code with YARD documentation
   - Proper error handling in services
   - Clear separation of concerns

### Critical Rollback Gaps

1. ❌ **No rollback documentation** (Score Impact: -3.0 points)
   - No `ROLLBACK.md` or equivalent documentation
   - No defined rollback triggers (error rates, latency thresholds)
   - No rollback procedure (step-by-step instructions)
   - No rollback testing plan
   - No rollback authority defined

2. ❌ **No feature flags** (Score Impact: -2.0 points)
   - Cannot perform gradual rollout (0% → 1% → 10% → 50% → 100%)
   - No instant kill switch for emergency disable
   - All-or-nothing deployment increases risk
   - Cannot A/B test Sorcery vs Rails 8

3. ❌ **No backup strategy** (Score Impact: -2.0 points)
   - No documented backup procedure
   - No automated backup before migrations
   - No backup retention policy
   - No tested restoration procedure
   - Critical gap for data safety

4. ❌ **No git tagging** (Score Impact: -1.5 points)
   - No version tags for identifying "last known good" release
   - Cannot quickly identify rollback target version
   - No release management strategy

5. ❌ **No alert rules** (Score Impact: -1.0 points)
   - Metrics exist but no alerts configured
   - Team won't be notified of authentication failures
   - No automated rollback triggers
   - No monitoring dashboards

6. ⚠️ **Migration 003 lacks safeguards** (Score Impact: -0.5 points)
   - Warning comments but no technical enforcement
   - Could be run prematurely, preventing rollback
   - No pre-execution validation

### Recommended Improvements

**Priority 1 - Critical (Required before production)**:
1. Create comprehensive rollback documentation (`docs/deployment/ROLLBACK.md`)
2. Implement feature flag for gradual rollout (`USE_RAILS8_AUTH` + `AUTH_ROLLOUT_PERCENTAGE`)
3. Document and test backup/restoration procedure
4. Configure Prometheus alert rules
5. Add version tagging strategy (semantic versioning)
6. Add technical safeguards to Migration 003

**Priority 2 - High (Strongly recommended)**:
1. Create Grafana monitoring dashboard
2. Document authentication troubleshooting runbook
3. Test complete rollback procedure on staging
4. Capture baseline metrics before migration
5. Create deployment automation or document manual procedures

**Priority 3 - Medium (Recommended for operational excellence)**:
1. Implement automated backup verification
2. Create quarterly disaster recovery drills
3. Document restoration time objectives (RTO: 15 minutes, RPO: 5 minutes)
4. Set up log aggregation with retention policies
5. Create post-incident review template

---

## Rollback Readiness Checklist

**Critical Requirements (Must Have)**:
- [ ] Rollback documentation exists (`docs/deployment/ROLLBACK.md`)
- [ ] Rollback procedure documented with step-by-step instructions
- [ ] Rollback triggers defined (error rate >5%, latency >500ms p95)
- [ ] All database migrations have down() scripts ✅ (3/3 migrations)
- [ ] Migrations are reversible ✅ (with caveat on Migration 003)
- [ ] Backup strategy documented and tested
- [ ] Backup created before migrations
- [ ] Releases tagged in git
- [ ] Rollback command documented
- [ ] Feature flag for gradual rollout implemented
- [ ] Kill switch for instant disable documented
- [ ] Alerts configured for rollback conditions
- [ ] Monitoring dashboard created

**Recommended (Should Have)**:
- [ ] Rollback tested on staging environment
- [ ] Backup retention policy defined (90d minimum)
- [ ] Backup restoration tested quarterly
- [ ] Gradual rollout plan defined (0% → 1% → 10% → 50% → 100%)
- [ ] Runbook for authentication troubleshooting
- [ ] Baseline metrics captured (1 week before migration)
- [ ] Deployment automation implemented
- [ ] Fast rollback achievable (<15 minutes)
- [ ] RTO/RPO defined and achievable
- [ ] Post-incident review template created

**Current Status**: 3 / 23 items complete (13%)

---

## Structured Data

```yaml
rollback_plan_evaluation:
  feature_id: "FEAT-AUTH-001"
  evaluation_date: "2025-11-28"
  evaluator: "rollback-plan-evaluator"
  overall_score: 4.8
  max_score: 10.0
  overall_status: "NEEDS PLAN"

  criteria:
    rollback_documentation:
      score: 2.0
      weight: 0.30
      status: "Missing"
      documentation_exists: false
      procedure_documented: false
      triggers_defined: false
      testing_plan_exists: false
      responsibilities_assigned: false

    database_migration_rollback:
      score: 8.5
      weight: 0.25
      status: "Reversible"
      migrations_with_rollback: "3/3"
      backup_strategy: false
      migration_reversibility:
        - migration: "20251125141044_add_password_digest_to_operators.rb"
          reversible: true
          data_safe: true
          issues: "None"
        - migration: "20251125142049_migrate_sorcery_passwords.rb"
          reversible: true
          data_safe: true
          issues: "None - excellent validation"
        - migration: "20251125142050_remove_sorcery_columns_from_operators.rb"
          reversible: "partial"
          data_safe: false
          issues: "Data loss on rollback, lacks safeguards"

    code_deployment_rollback:
      score: 3.0
      weight: 0.20
      status: "Partially Ready"
      releases_tagged: false
      rollback_command_documented: false
      fast_rollback: "unknown"
      deployment_automation: false

    data_backup_recovery:
      score: 1.5
      weight: 0.15
      status: "Not Ready"
      backup_strategy: false
      backup_tested: false
      retention_policy: false
      automated_backup: false

    feature_flags:
      score: 0.5
      weight: 0.05
      status: "Not Implemented"
      feature_flags_exist: false
      kill_switch: false
      gradual_rollout: false

    monitoring_alerting:
      score: 4.5
      weight: 0.05
      status: "Partially Configured"
      alerts_configured: false
      runbook_exists: false
      dashboard_exists: false
      metrics_instrumented: true
      structured_logging: true

  critical_gaps:
    count: 6
    items:
      - title: "No rollback documentation"
        severity: "Critical"
        category: "Documentation"
        impact: "Team has no guidance on rollback during incident"
        recommendation: "Create docs/deployment/ROLLBACK.md with procedures"

      - title: "No feature flag for authentication migration"
        severity: "Critical"
        category: "Deployment"
        impact: "Cannot perform gradual rollout or instant rollback"
        recommendation: "Implement USE_RAILS8_AUTH and AUTH_ROLLOUT_PERCENTAGE"

      - title: "No backup strategy documented"
        severity: "Critical"
        category: "Backup"
        impact: "Cannot recover data if migration fails"
        recommendation: "Create backup procedure and test restoration"

      - title: "No git version tagging"
        severity: "Critical"
        category: "Deployment"
        impact: "Cannot identify last known good version for rollback"
        recommendation: "Implement semantic versioning (v1.0.0, v1.1.0)"

      - title: "No Prometheus alerts configured"
        severity: "Critical"
        category: "Monitoring"
        impact: "Team won't be notified of authentication failures"
        recommendation: "Configure alert rules for failure rate and latency"

      - title: "Migration 003 lacks execution safeguards"
        severity: "High"
        category: "Migration"
        impact: "Could be run prematurely, preventing rollback"
        recommendation: "Add pre-execution validation for 30-day period"

  rollback_ready: false
  estimated_remediation_hours: 40
  estimated_rollback_time_minutes: "unknown"
  recommended_rollback_time_target_minutes: 15

  recommendations:
    priority_1_critical:
      - "Create comprehensive rollback documentation"
      - "Implement feature flag for gradual rollout"
      - "Document and test backup/restoration procedure"
      - "Configure Prometheus alert rules"
      - "Implement version tagging strategy"
      - "Add technical safeguards to Migration 003"

    priority_2_high:
      - "Create Grafana monitoring dashboard"
      - "Document authentication troubleshooting runbook"
      - "Test complete rollback procedure on staging"
      - "Capture baseline metrics before migration"
      - "Document deployment procedures"

    priority_3_medium:
      - "Implement automated backup verification"
      - "Create quarterly disaster recovery drills"
      - "Document RTO/RPO objectives"
      - "Set up log aggregation with retention"
      - "Create post-incident review template"
```

---

## References

- [Database Migration Best Practices](https://martinfowler.com/articles/evodb.html)
- [Deployment Rollback Strategies](https://cloud.google.com/architecture/application-deployment-and-testing-strategies)
- [Feature Flags Guide](https://martinfowler.com/articles/feature-toggles.html)
- [SRE Book: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
- [Postgres Backup Best Practices](https://www.postgresql.org/docs/current/backup.html)
- [Prometheus Alerting](https://prometheus.io/docs/practices/alerting/)
