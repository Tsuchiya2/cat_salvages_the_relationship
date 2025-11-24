# Task Plan - MySQL 8 Database Unification

**Feature ID**: FEAT-DB-001
**Design Document**: docs/designs/mysql8-unification.md
**Created**: 2025-11-24
**Planner**: planner agent

---

## Metadata

```yaml
task_plan_metadata:
  feature_id: "FEAT-DB-001"
  feature_name: "MySQL 8 Database Unification"
  total_tasks: 35
  estimated_duration: "4 weeks"
  critical_path: ["TASK-001", "TASK-005", "TASK-010", "TASK-015", "TASK-020", "TASK-025", "TASK-030", "TASK-033"]
  parallel_opportunities: 12
```

---

## 1. Overview

**Feature Summary**: Migrate all environments (development, test, production) from PostgreSQL to MySQL 8.0+ to achieve environment parity and eliminate database-specific issues.

**Total Tasks**: 35
**Execution Phases**: 7 (Infrastructure → Configuration → Observability → Extensibility → Migration → Testing → Deployment)
**Parallel Opportunities**: 12 tasks can run in parallel across phases

**Critical Success Factors**:
- Zero data loss during migration
- Downtime < 30 minutes for production migration
- All tests passing on MySQL 8
- Comprehensive observability infrastructure
- Reusable migration framework for future use

---

## 2. Task Breakdown

### Phase 1: Infrastructure Setup (Week 1, Days 1-2)

#### TASK-001: Provision MySQL 8 Production Instance
**Description**: Set up MySQL 8.0+ instance in production environment with appropriate resources and security configuration.

**Dependencies**: None

**Deliverables**:
- Production MySQL 8 instance running (version 8.0.34+ recommended)
- Instance accessible from application servers
- Root credentials secured in password manager
- Instance configuration documented in `docs/infrastructure/mysql8-setup.md`

**Definition of Done**:
- MySQL 8 instance responds to ping/connection test
- Version verified: `SELECT VERSION()` returns 8.0.x
- Can connect from application server using mysql client
- Resource allocation documented (CPU, RAM, Storage)

**Estimated Complexity**: Medium
**Assigned To**: Human (DevOps/Infrastructure team)
**Estimated Duration**: 4 hours

---

#### TASK-002: Create MySQL Database Users and Permissions
**Description**: Create application user and migration user with appropriate permissions following principle of least privilege.

**Dependencies**: [TASK-001]

**Deliverables**:
- Application user `reline_app` created with SELECT, INSERT, UPDATE, DELETE permissions
- Migration user `reline_migrate` created with ALL PRIVILEGES
- Both users require SSL connection
- Both users use caching_sha2_password authentication
- Credentials stored in environment variables
- SQL script saved in `db/setup/create_mysql_users.sql`

**Definition of Done**:
- Application user can connect and perform CRUD operations
- Application user cannot perform DDL operations (CREATE, DROP, ALTER)
- Migration user can perform schema changes
- SSL requirement verified
- Credentials documented in password manager

**Estimated Complexity**: Low
**Assigned To**: Human (DevOps)
**Estimated Duration**: 1 hour

---

#### TASK-003: Configure SSL/TLS for MySQL Connection
**Description**: Generate SSL certificates and configure MySQL server and client for encrypted connections.

**Dependencies**: [TASK-001]

**Deliverables**:
- SSL certificates generated or obtained
- Certificates stored in `/etc/mysql/certs/` on server and application server
- MySQL server configured with `require_secure_transport=ON`
- Certificate paths documented in `docs/infrastructure/ssl-setup.md`
- Environment variables configured: `DB_SSL_CA`, `DB_SSL_KEY`, `DB_SSL_CERT`

**Definition of Done**:
- MySQL server requires SSL connections
- Application can connect using SSL
- Certificate verification succeeds
- Non-SSL connections rejected

**Estimated Complexity**: Medium
**Assigned To**: Human (DevOps)
**Estimated Duration**: 2 hours

---

#### TASK-004: Set Up Development and Test MySQL 8 Instances
**Description**: Ensure local development and test environments have MySQL 8.0+ installed and configured.

**Dependencies**: None (can run in parallel with TASK-001)

**Deliverables**:
- MySQL 8.0+ installed locally (via Homebrew, apt, or other package manager)
- Local databases created: `reline_development`, `reline_test`
- Local user configured with full permissions
- Installation instructions updated in `README.md`

**Definition of Done**:
- `mysql --version` shows 8.0.x
- Can create and drop test databases
- Character set: utf8mb4
- Collation: utf8mb4_unicode_ci

**Estimated Complexity**: Low
**Assigned To**: AI (with human verification)
**Estimated Duration**: 1 hour

---

### Phase 2: Configuration Updates (Week 1, Days 3-4)

#### TASK-005: Update database.yml for MySQL 8
**Description**: Modify Rails database configuration to use mysql2 adapter for all environments with production-specific settings.

**Dependencies**: None (can start in parallel with Phase 1)

**Deliverables**:
- File: `config/database.yml`
- All environments use mysql2 adapter
- Production includes SSL configuration
- Environment variables used for all credentials
- Connection pool settings optimized (development: 5, test: 5, production: 10)
- Timeout and reconnect settings configured

**Definition of Done**:
- Configuration validates (no syntax errors)
- All environments explicitly use mysql2 adapter
- No hardcoded credentials
- SSL parameters present for production
- Encoding set to utf8mb4
- Collation set to utf8mb4_unicode_ci

**Estimated Complexity**: Low
**Assigned To**: AI
**Estimated Duration**: 30 minutes

**Code Review Required**: Yes

---

#### TASK-006: Update Gemfile Dependencies
**Description**: Update Gemfile to use mysql2 gem for all environments and remove pg gem dependency.

**Dependencies**: None (can run in parallel with TASK-005)

**Deliverables**:
- File: `Gemfile`
- `mysql2` gem version ~> 0.5 added globally
- `pg` gem removed (including production group)
- Updated `Gemfile.lock` generated

**Definition of Done**:
- `bundle install` succeeds
- No pg gem in Gemfile or Gemfile.lock
- mysql2 gem version 0.5.x installed
- No dependency conflicts

**Estimated Complexity**: Low
**Assigned To**: AI
**Estimated Duration**: 15 minutes

**Code Review Required**: Yes

---

#### TASK-007: Review and Update ActiveRecord Migrations
**Description**: Review all existing migrations for PostgreSQL-specific syntax and ensure MySQL 8 compatibility.

**Dependencies**: [TASK-005, TASK-006]

**Deliverables**:
- All migration files reviewed (in `db/migrate/`)
- List of incompatible migrations documented in `docs/migration-review.md`
- Required changes identified
- No PostgreSQL-specific types used (e.g., hstore, jsonb, array)

**Definition of Done**:
- All migrations reviewed
- No PostgreSQL-specific syntax found (or documented for update)
- Migrations tested on clean MySQL 8 database
- schema.rb regenerated from MySQL 8

**Estimated Complexity**: Low (based on schema analysis showing standard SQL types)
**Assigned To**: AI
**Estimated Duration**: 1 hour

---

#### TASK-008: Set Up Environment Variables
**Description**: Configure environment variables for MySQL connection parameters in all environments.

**Dependencies**: [TASK-002, TASK-003]

**Deliverables**:
- `.env.example` file updated with MySQL connection variables
- Production environment variables documented in deployment guide
- Development/test `.env` file configured (gitignored)
- Documentation: `docs/environment-variables.md`

**Definition of Done**:
- All required variables documented: DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD, DB_SSL_CA, DB_SSL_KEY, DB_SSL_CERT
- `.env.example` updated
- `.env` added to `.gitignore` (if not already)
- Development/test configurations working with env vars

**Estimated Complexity**: Low
**Assigned To**: AI
**Estimated Duration**: 30 minutes

---

### Phase 3: Observability Infrastructure (Week 1, Day 5 - Week 2, Day 1)

#### TASK-009: Implement Semantic Logger with JSON Format
**Description**: Add semantic_logger gem and configure structured logging with JSON output for migration tracking.

**Dependencies**: [TASK-006]

**Deliverables**:
- File: `config/initializers/semantic_logger.rb`
- File: `lib/database_migration/logger.rb`
- semantic_logger gem added to Gemfile
- JSON format logging configured
- Migration-specific logger module created
- Log methods: `log_migration_start`, `log_table_migration`, `log_migration_error`

**Definition of Done**:
- Semantic logger outputs JSON format
- Migration logger module defined
- All log methods tested and working
- Logs written to STDOUT and file

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 2 hours

**Code Review Required**: Yes

---

#### TASK-010: Configure Centralized Log Aggregation
**Description**: Set up log rotation and configure centralized logging for production environment.

**Dependencies**: [TASK-009]

**Deliverables**:
- File: `config/logging.yml`
- Log rotation configured (max 100MB, 10 files)
- Separate migration log file: `/var/log/reline/migration.log`
- Syslog appender configured (optional, based on infrastructure)
- Log paths: production.log, migration.log, audit.log

**Definition of Done**:
- Log rotation working correctly
- Migration events logged to separate file
- Log files created with correct permissions
- Old logs cleaned up based on retention policy

**Estimated Complexity**: Medium
**Assigned To**: AI (config) + Human (infrastructure setup)
**Estimated Duration**: 2 hours

---

#### TASK-011: Implement Prometheus Metrics Exporter
**Description**: Add prometheus-client gem and implement database-specific metrics collection.

**Dependencies**: [TASK-006]

**Deliverables**:
- File: `config/initializers/prometheus.rb`
- File: `lib/database_metrics.rb`
- prometheus-client gem added to Gemfile
- Metrics defined: database_pool_size, database_pool_available, database_pool_waiting, database_query_duration_seconds, migration_progress_percent, migration_errors_total
- Metrics endpoint exposed: `/metrics`

**Definition of Done**:
- Prometheus metrics endpoint accessible
- All 6 metric types implemented
- Pool metrics update every 10 seconds
- Query duration histogram configured with appropriate buckets

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 3 hours

**Code Review Required**: Yes

---

#### TASK-012: Create Grafana Dashboard Configuration
**Description**: Design Grafana dashboard JSON configuration for MySQL migration monitoring.

**Dependencies**: [TASK-011]

**Deliverables**:
- File: `config/grafana/mysql8-migration-dashboard.json`
- Dashboard includes 3 panels:
  1. Database Connection Pool
  2. Query Performance (95th Percentile)
  3. Migration Progress
- PromQL queries defined for each panel
- Dashboard importable via Grafana UI

**Definition of Done**:
- Dashboard JSON validates
- All panels display data when Prometheus connected
- Dashboard documented in `docs/observability/grafana-setup.md`
- Screenshots of dashboard included in documentation

**Estimated Complexity**: Medium
**Assigned To**: AI (JSON) + Human (Grafana setup)
**Estimated Duration**: 2 hours

---

#### TASK-013: Configure Alerting Rules
**Description**: Define Prometheus alerting rules for database migration and performance monitoring.

**Dependencies**: [TASK-011]

**Deliverables**:
- File: `config/alerting_rules.yml`
- 4 alert rules defined:
  1. HighDatabaseConnectionPoolUsage (warning: > 80% for 2min)
  2. SlowDatabaseQueries (warning: 95th percentile > 200ms for 5min)
  3. MigrationErrors (critical: any errors in 5min)
  4. DatabaseConnectionFailure (critical: connection down for 1min)
- Alert annotations include summary and description

**Definition of Done**:
- Alert rules validate with Prometheus
- Test alerts trigger correctly
- Alert notifications configured (email/Slack)
- Documented in `docs/observability/alerting.md`

**Estimated Complexity**: Medium
**Assigned To**: AI (config) + Human (notification setup)
**Estimated Duration**: 2 hours

---

#### TASK-014: Implement OpenTelemetry Distributed Tracing
**Description**: Add OpenTelemetry instrumentation for database operations and migration tracking.

**Dependencies**: [TASK-006]

**Deliverables**:
- File: `config/initializers/opentelemetry.rb`
- File: `lib/database_migration/tracing.rb`
- opentelemetry-sdk and opentelemetry-instrumentation-all gems added
- ActiveRecord instrumentation enabled
- Custom migration tracing implemented
- Trace attributes: operation, timestamp, status, error

**Definition of Done**:
- OpenTelemetry configured and running
- Database queries traced
- Migration operations create spans
- Traces exported to collector (if configured)

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 2 hours

**Code Review Required**: Yes

---

#### TASK-015: Implement Health Check Endpoints
**Description**: Create health check controller with database status and migration status endpoints.

**Dependencies**: [TASK-005]

**Deliverables**:
- File: `app/controllers/health_controller.rb`
- Routes added: `GET /health`, `GET /health/migration`
- Endpoints return JSON with database status
- Health checks: database_reachable, migrations_current, sample_query_works
- Migration status includes: migration_in_progress, current_database, adapter info

**Definition of Done**:
- Both endpoints respond with 200 OK when healthy
- Database failures return appropriate error status
- Migration in progress flag detectable
- Documented in `docs/api/health-endpoints.md`

**Estimated Complexity**: Low
**Assigned To**: AI
**Estimated Duration**: 1 hour

**Code Review Required**: Yes

---

### Phase 4: Extensibility Framework (Week 2, Days 2-3)

#### TASK-016: Create Database Adapter Abstraction Layer
**Description**: Implement adapter pattern for database operations to enable future migrations.

**Dependencies**: [TASK-006]

**Deliverables**:
- File: `lib/database_adapter/base.rb` (interface)
- File: `lib/database_adapter/mysql8_adapter.rb`
- File: `lib/database_adapter/postgresql_adapter.rb`
- File: `lib/database_adapter/factory.rb`
- Methods: adapter_name, migrate_from, verify_compatibility, connection_params, version_info

**Definition of Done**:
- Base adapter interface defined
- MySQL8Adapter fully implemented
- PostgreSQLAdapter fully implemented
- Factory pattern creates correct adapter
- All methods have RSpec tests (coverage >= 90%)

**Estimated Complexity**: High
**Assigned To**: AI
**Estimated Duration**: 4 hours

**Code Review Required**: Yes

---

#### TASK-017: Create Migration Strategy Framework
**Description**: Implement strategy pattern for different migration approaches (pgloader, custom ETL, dump/load).

**Dependencies**: [TASK-016]

**Deliverables**:
- File: `lib/database_migration/framework.rb`
- File: `lib/database_migration/strategies/base.rb`
- File: `lib/database_migration/strategies/postgresql_to_mysql8_strategy.rb`
- File: `lib/database_migration/strategy_factory.rb`
- Methods: execute, validate_prerequisites, prepare, migrate, verify, cleanup

**Definition of Done**:
- Framework supports pluggable strategies
- PostgreSQL to MySQL 8 strategy implemented
- Strategy factory creates correct strategy
- All strategies follow base interface
- RSpec tests for framework (coverage >= 90%)

**Estimated Complexity**: High
**Assigned To**: AI
**Estimated Duration**: 5 hours

**Code Review Required**: Yes

---

#### TASK-018: Implement Database Version Manager
**Description**: Create version compatibility checking and upgrade path management.

**Dependencies**: [TASK-016]

**Deliverables**:
- File: `config/database_version_requirements.yml`
- File: `lib/database_version_manager/version_compatibility.rb`
- File: `config/initializers/database_version_check.rb`
- Version requirements: minimum, recommended, deprecated versions
- Methods: verify_version!, current_version, upgrade_path

**Definition of Done**:
- Version requirements defined for MySQL 8 and PostgreSQL
- Version check runs on Rails initialization
- Unsupported versions raise clear error
- Deprecated versions log warning
- RSpec tests for version manager

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 3 hours

**Code Review Required**: Yes

---

#### TASK-019: Create Reusable Migration Components
**Description**: Implement generic utilities for data verification, backup, connection management.

**Dependencies**: [TASK-016, TASK-017]

**Deliverables**:
- File: `lib/migration_utils/data_verifier.rb`
- File: `lib/database_migration/services/backup_service.rb`
- File: `lib/database_migration/services/connection_manager.rb`
- File: `lib/database_migration/migration_config.rb`
- File: `config/database_migration.yml`

**Definition of Done**:
- DataVerifier can compare row counts, schemas, checksums
- BackupService supports PostgreSQL and MySQL backups
- ConnectionManager establishes connections for any adapter
- MigrationConfig loads from YAML file
- All components have RSpec tests (coverage >= 90%)

**Estimated Complexity**: High
**Assigned To**: AI
**Estimated Duration**: 6 hours

**Code Review Required**: Yes

---

#### TASK-020: Implement Migration Progress Tracker
**Description**: Create progress tracking system with web-based viewer and Prometheus integration.

**Dependencies**: [TASK-011, TASK-017]

**Deliverables**:
- File: `lib/database_migration/progress_tracker.rb`
- File: `app/controllers/admin/migration_status_controller.rb`
- Route: `GET /admin/migration/status` (admin only)
- Progress stored in `tmp/migration_progress.json`
- Prometheus metrics updated in real-time

**Definition of Done**:
- Progress tracker updates per-table progress
- Overall progress calculated correctly
- Web endpoint returns JSON progress
- Progress persisted to file
- Prometheus migration_progress_percent metric updated

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 3 hours

**Code Review Required**: Yes

---

### Phase 5: Migration Scripts and Testing (Week 2, Days 4-5 + Week 3)

#### TASK-021: Install and Configure pgloader
**Description**: Install pgloader tool and create configuration template for PostgreSQL to MySQL migration.

**Dependencies**: [TASK-001]

**Deliverables**:
- pgloader installed on migration server
- File: `lib/database_migration/templates/pgloader.load.erb`
- Configuration includes: worker count, type casting rules, encoding settings
- Installation instructions in `docs/migration/pgloader-setup.md`

**Definition of Done**:
- pgloader version 3.6+ installed
- Template renders valid pgloader configuration
- Template includes all required type conversions
- Documented: workers=8, utf8mb4 charset, datetime casting rules

**Estimated Complexity**: Medium
**Assigned To**: Human (installation) + AI (template)
**Estimated Duration**: 2 hours

---

#### TASK-022: Create Data Migration Verification Script
**Description**: Implement Ruby script to verify data integrity after migration (row counts, checksums).

**Dependencies**: [TASK-019]

**Deliverables**:
- File: `lib/database_migration/verify_migration.rb`
- Script connects to both PostgreSQL and MySQL
- Verifies row counts for all tables
- Calculates and compares data checksums (sample-based)
- Outputs detailed report to STDOUT and JSON file
- Uses DataVerifier component

**Definition of Done**:
- Script runs without errors
- All 5 tables verified: alarm_contents, contents, feedbacks, line_groups, operators
- Mismatches clearly reported
- JSON report saved to `tmp/migration_verification_TIMESTAMP.json`
- Exit code 0 if all match, 1 if mismatches found

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 2 hours

**Code Review Required**: Yes

---

#### TASK-023: Create Rollback Script
**Description**: Implement automated rollback script to revert to PostgreSQL if migration fails.

**Dependencies**: [TASK-005, TASK-006]

**Deliverables**:
- File: `scripts/rollback_to_postgresql.sh`
- Script stops application
- Reverts database.yml and Gemfile to PostgreSQL configuration
- Runs bundle install
- Verifies PostgreSQL connection
- Restarts application
- Outputs clear status messages

**Definition of Done**:
- Script executable: `chmod +x scripts/rollback_to_postgresql.sh`
- All steps automated (no manual intervention)
- Rollback completes in < 10 minutes
- Application successfully running on PostgreSQL after rollback
- Script tested on staging environment

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 2 hours

**Code Review Required**: Yes
**Testing Required**: Must be tested on staging

---

#### TASK-024: Create Maintenance Mode Middleware
**Description**: Implement Rails middleware to display maintenance page during migration.

**Dependencies**: [TASK-005]

**Deliverables**:
- File: `config/initializers/maintenance_mode.rb`
- File: `app/middleware/maintenance_middleware.rb`
- Maintenance triggered by presence of `tmp/maintenance.txt`
- Returns HTTP 503 with HTML maintenance page
- Middleware added to Rails middleware stack

**Definition of Done**:
- Creating `tmp/maintenance.txt` enables maintenance mode
- All requests return 503 status
- HTML page displays user-friendly message
- Removing file disables maintenance mode
- Tested locally

**Estimated Complexity**: Low
**Assigned To**: AI
**Estimated Duration**: 1 hour

**Code Review Required**: Yes

---

#### TASK-025: Run Full RSpec Test Suite on MySQL 8
**Description**: Execute all RSpec tests against MySQL 8 database and fix any failures.

**Dependencies**: [TASK-005, TASK-006, TASK-007]

**Deliverables**:
- All RSpec tests passing on MySQL 8
- Test results documented in `docs/testing/mysql8-test-results.md`
- Any failures fixed (code or test updates)
- Test coverage report generated
- No PostgreSQL-specific test code remaining

**Definition of Done**:
- `bundle exec rspec` exits with 0
- All tests green (100% pass rate)
- No pending/skipped tests
- Test coverage >= 90%
- Both unit and system tests passing

**Estimated Complexity**: Medium (assumes minimal compatibility issues based on schema analysis)
**Assigned To**: AI (run tests) + Human (review failures)
**Estimated Duration**: 4 hours

**Code Review Required**: Yes (for any code changes)

---

#### TASK-026: Create Database Adapter Compatibility Test Suite
**Description**: Write RSpec tests to verify MySQL 8 compatibility (encoding, collation, timestamps, etc.).

**Dependencies**: [TASK-025]

**Deliverables**:
- File: `spec/support/database_adapter_spec.rb`
- Tests verify: mysql2 adapter, utf8mb4 encoding, utf8mb4_unicode_ci collation
- File: `spec/integration/mysql_compatibility_spec.rb`
- Tests verify: timestamp precision, unicode handling, case sensitivity, large text fields, concurrent writes

**Definition of Done**:
- All compatibility tests passing
- Tests cover edge cases from design doc section 9.3
- Test examples: emoji support, timestamp microseconds, collation case-insensitivity
- Tests documented with clear descriptions

**Estimated Complexity**: Medium
**Assigned To**: AI
**Estimated Duration**: 3 hours

**Code Review Required**: Yes

---

#### TASK-027: Set Up Staging Environment
**Description**: Provision and configure staging environment identical to production for migration rehearsal.

**Dependencies**: [TASK-001, TASK-002, TASK-003]

**Deliverables**:
- Staging MySQL 8 instance provisioned
- Staging PostgreSQL database created with production data copy (anonymized)
- Application deployed to staging
- Staging environment documented in `docs/infrastructure/staging-environment.md`
- Environment variables configured

**Definition of Done**:
- Staging application running on PostgreSQL
- Staging database contains realistic data volume
- Can access staging application
- Monitoring configured for staging
- Ready for migration rehearsal

**Estimated Complexity**: High
**Assigned To**: Human (DevOps)
**Estimated Duration**: 6 hours

---

#### TASK-028: Perform Staging Migration Rehearsal
**Description**: Execute complete migration process on staging environment as final validation.

**Dependencies**: [TASK-021, TASK-022, TASK-023, TASK-024, TASK-027]

**Deliverables**:
- Migration executed on staging
- Migration duration measured
- Data verification passed
- Application tested on staging MySQL 8
- Issues identified and resolved
- Migration steps refined based on learnings
- Detailed report: `docs/migration/staging-migration-report.md`

**Definition of Done**:
- Staging migration completed successfully
- All data verified (row counts match)
- Application functional on staging MySQL 8
- Migration completed within target time (< 30min downtime)
- Rollback tested successfully
- Team confident in production migration

**Estimated Complexity**: High
**Assigned To**: Human (execute) + AI (verify)
**Estimated Duration**: 4 hours + 24 hours monitoring

**Critical Milestone**: No production migration without successful staging migration

---

#### TASK-029: Performance Testing and Optimization
**Description**: Run load tests on staging MySQL 8 and optimize queries/indexes as needed.

**Dependencies**: [TASK-028]

**Deliverables**:
- Load test results using Apache Bench or similar tool
- Query performance analysis (EXPLAIN for key queries)
- Index optimization recommendations
- MySQL configuration tuning (if needed)
- Performance report: `docs/performance/mysql8-benchmarks.md`
- Comparison: PostgreSQL vs MySQL 8 performance

**Definition of Done**:
- 95th percentile query time < 200ms
- No missing indexes on frequently queried columns
- Load test: 1000 requests, 10 concurrent connections successful
- No slow queries logged (> 1 second)
- Performance meets or exceeds PostgreSQL baseline

**Estimated Complexity**: Medium
**Assigned To**: Human (load testing) + AI (analysis)
**Estimated Duration**: 4 hours

---

### Phase 6: Production Migration Preparation (Week 4, Days 1-2)

#### TASK-030: Create Production Migration Runbook
**Description**: Write detailed step-by-step guide for production migration execution.

**Dependencies**: [TASK-028, TASK-029]

**Deliverables**:
- File: `docs/migration/production-migration-runbook.md`
- Step-by-step instructions with commands
- Timeline with estimated durations
- Verification checkpoints
- Rollback triggers (when to abort)
- Team roles and responsibilities
- Communication plan (status updates)

**Definition of Done**:
- Runbook reviewed by entire team
- All commands tested on staging
- Timeline validated from staging rehearsal
- Success criteria clearly defined
- Rollback procedure included
- Contact information for escalation

**Estimated Complexity**: Medium
**Assigned To**: AI (draft) + Human (review and refine)
**Estimated Duration**: 3 hours

**Critical Milestone**: Runbook approval required before scheduling production migration

---

#### TASK-031: Update Documentation (README, Setup Guides)
**Description**: Update all developer documentation to reflect MySQL 8 requirement.

**Dependencies**: [TASK-004, TASK-008]

**Deliverables**:
- File: `README.md` updated with MySQL 8 setup instructions
- File: `docs/development-setup.md` updated
- File: `docs/troubleshooting.md` with MySQL-specific issues
- File: `docs/database-operations.md` (backup, restore, migrations)
- PostgreSQL references removed

**Definition of Done**:
- README clearly states MySQL 8.0+ requirement
- Step-by-step installation instructions for macOS, Ubuntu
- Environment variable setup documented
- Common issues and solutions documented
- All PostgreSQL references removed or marked as legacy

**Estimated Complexity**: Low
**Assigned To**: AI
**Estimated Duration**: 2 hours

**Code Review Required**: Yes

---

#### TASK-032: Pre-Deployment Checklist Verification
**Description**: Verify all items on pre-deployment checklist from design doc section 12.1.

**Dependencies**: [TASK-001 through TASK-031]

**Deliverables**:
- Checklist verification report: `docs/migration/pre-deployment-verification.md`
- All checklist items verified and documented
- Any blockers identified and resolved
- Sign-off from team lead

**Definition of Done**:
- All 11 checklist items verified:
  1. MySQL 8 instance ready
  2. Users and permissions configured
  3. SSL/TLS configured
  4. Staging migration successful
  5. Tests passing on staging
  6. Performance benchmarks met
  7. Rollback tested
  8. Backups verified
  9. Maintenance window scheduled
  10. Team notified
  11. Monitoring configured
- Any issues documented and resolved
- Team approval to proceed

**Estimated Complexity**: Low
**Assigned To**: Human (verification lead)
**Estimated Duration**: 2 hours

**Critical Gate**: Cannot proceed to production without checklist approval

---

### Phase 7: Production Migration Execution (Week 4, Day 3)

#### TASK-033: Execute Production Migration
**Description**: Perform production database migration from PostgreSQL to MySQL 8 following runbook.

**Dependencies**: [TASK-032]

**Deliverables**:
- Production migration completed
- Data verification passed (all row counts match)
- Application running on MySQL 8
- Migration execution log: `logs/production-migration-TIMESTAMP.log`
- Post-migration verification report
- Maintenance mode disabled

**Definition of Done**:
- Migration completed within 30-minute maintenance window
- All tables migrated: alarm_contents, contents, feedbacks, line_groups, operators
- Row counts: PostgreSQL == MySQL (100% match)
- Application responds to health checks
- Smoke tests passing
- No critical errors in logs
- Team notified of completion

**Estimated Complexity**: Critical
**Assigned To**: Human (team effort)
**Estimated Duration**: 2-3 hours (30min maintenance window + 2.5hr monitoring)

**Critical Milestone**: Production migration completion

---

#### TASK-034: Post-Migration Monitoring (24 hours)
**Description**: Monitor production system for 24 hours post-migration and address any issues.

**Dependencies**: [TASK-033]

**Deliverables**:
- Monitoring report: `docs/migration/post-migration-monitoring-report.md`
- Metrics tracked: response time, query time, error rate, connection pool, memory
- Any issues identified and resolved
- Performance comparison: pre-migration vs post-migration

**Definition of Done**:
- 24 hours of stable operation
- No critical incidents
- Performance metrics meet targets:
  - Response time 95th percentile < 200ms
  - Query time average < 50ms
  - Error rate < 0.1%
  - Connection pool usage < 80%
- All alerts reviewed and addressed
- Team satisfied with migration success

**Estimated Complexity**: Medium
**Assigned To**: Human (on-call rotation)
**Estimated Duration**: 24 hours

---

#### TASK-035: Cleanup and Documentation Finalization
**Description**: Clean up temporary resources, finalize documentation, and plan PostgreSQL decommissioning.

**Dependencies**: [TASK-034]

**Deliverables**:
- PostgreSQL instance retention plan (30 days)
- Temporary migration files cleaned up
- Final migration report: `docs/migration/final-migration-report.md`
- Lessons learned documented
- Team retrospective conducted
- PostgreSQL decommissioning scheduled (Week 8)

**Definition of Done**:
- All temporary migration files removed from app servers
- Migration scripts archived to documentation
- PostgreSQL backup retention policy set (30 days)
- Final report includes: timeline, issues, resolutions, metrics, lessons learned
- Team retrospective completed
- PostgreSQL decommissioning date set

**Estimated Complexity**: Low
**Assigned To**: Human (team lead)
**Estimated Duration**: 2 hours

---

## 3. Execution Sequence

### Phase 1: Infrastructure Setup (Week 1, Days 1-2)
**Critical Path**: TASK-001 → TASK-002, TASK-003

**Parallel Opportunities**:
- TASK-004 (local setup) can run in parallel with TASK-001, TASK-002, TASK-003

**Phase Completion Criteria**:
- All MySQL 8 instances accessible
- Users and permissions configured
- SSL/TLS working

---

### Phase 2: Configuration Updates (Week 1, Days 3-4)
**Critical Path**: TASK-005 → TASK-007

**Parallel Opportunities**:
- TASK-005 and TASK-006 can run in parallel
- TASK-008 can start after TASK-002 completes

**Phase Completion Criteria**:
- All configuration files updated
- Dependencies resolved
- Environment variables documented

---

### Phase 3: Observability Infrastructure (Week 1, Day 5 - Week 2, Day 1)
**Critical Path**: TASK-009 → TASK-010

**Parallel Opportunities**:
- TASK-011, TASK-014 can run in parallel (both depend on TASK-006)
- TASK-012, TASK-013 can run in parallel after TASK-011
- TASK-015 can run in parallel with observability tasks

**Phase Completion Criteria**:
- Structured logging implemented
- Metrics collection working
- Dashboards created
- Alerts configured
- Health checks available

---

### Phase 4: Extensibility Framework (Week 2, Days 2-3)
**Critical Path**: TASK-016 → TASK-017 → TASK-019

**Parallel Opportunities**:
- TASK-018 can run in parallel with TASK-017
- TASK-020 can start once TASK-017 and TASK-011 complete

**Phase Completion Criteria**:
- Adapter abstraction layer complete
- Migration strategies implemented
- Version management working
- Progress tracking operational

---

### Phase 5: Migration Scripts and Testing (Week 2, Days 4-5 + Week 3)
**Critical Path**: TASK-021 → TASK-022 → TASK-027 → TASK-028 → TASK-029

**Parallel Opportunities**:
- TASK-023, TASK-024 can run in parallel with TASK-021, TASK-022
- TASK-025, TASK-026 can run in parallel after TASK-007

**Phase Completion Criteria**:
- All migration tools ready
- Verification scripts tested
- Rollback procedure validated
- Staging migration successful
- Performance validated

---

### Phase 6: Production Migration Preparation (Week 4, Days 1-2)
**Critical Path**: TASK-030 → TASK-032

**Parallel Opportunities**:
- TASK-031 can run in parallel with TASK-030

**Phase Completion Criteria**:
- Runbook completed and approved
- Documentation updated
- Pre-deployment checklist verified
- Team ready for production migration

---

### Phase 7: Production Migration Execution (Week 4, Day 3+)
**Critical Path**: TASK-033 → TASK-034 → TASK-035

**No Parallel Opportunities**: These tasks must run sequentially

**Phase Completion Criteria**:
- Production migration successful
- System stable for 24 hours
- Documentation finalized
- PostgreSQL decommissioning scheduled

---

## 4. Risk Assessment

### High-Risk Tasks

**TASK-033 (Production Migration)**
- **Risk**: Data loss, extended downtime
- **Impact**: Critical
- **Mitigation**:
  - Staging rehearsal (TASK-028)
  - Automated rollback (TASK-023)
  - Multiple backups
  - Team on-call during migration

**TASK-028 (Staging Migration Rehearsal)**
- **Risk**: Unforeseen migration issues
- **Impact**: High (blocks production migration)
- **Mitigation**:
  - Test on realistic data volume
  - Document all issues
  - Iterate until successful
  - Do not proceed to production if staging fails

**TASK-025 (RSpec Test Suite)**
- **Risk**: Tests reveal compatibility issues
- **Impact**: Medium (delays timeline)
- **Mitigation**:
  - Early execution (Week 1)
  - Allocate buffer time for fixes
  - Involve backend team for complex issues

---

## 5. Dependencies Graph

```
Phase 1: Infrastructure
TASK-001 → TASK-002, TASK-003
TASK-004 (independent)

Phase 2: Configuration
TASK-005, TASK-006 (independent of Phase 1)
TASK-005, TASK-006 → TASK-007
TASK-002, TASK-003 → TASK-008

Phase 3: Observability
TASK-006 → TASK-009 → TASK-010
TASK-006 → TASK-011 → TASK-012, TASK-013
TASK-006 → TASK-014
TASK-005 → TASK-015

Phase 4: Extensibility
TASK-006 → TASK-016 → TASK-017 → TASK-019
TASK-016 → TASK-018
TASK-017, TASK-011 → TASK-020

Phase 5: Migration & Testing
TASK-001 → TASK-021 → TASK-027 → TASK-028 → TASK-029
TASK-019 → TASK-022
TASK-005, TASK-006 → TASK-023, TASK-024
TASK-007 → TASK-025 → TASK-026

Phase 6: Preparation
TASK-028, TASK-029 → TASK-030
TASK-008 → TASK-031
TASK-001 through TASK-031 → TASK-032

Phase 7: Execution
TASK-032 → TASK-033 → TASK-034 → TASK-035
```

---

## 6. Resource Allocation

### AI-Assigned Tasks (22 tasks)
- Configuration updates: TASK-005, TASK-006, TASK-007, TASK-008
- Observability: TASK-009, TASK-011, TASK-012, TASK-014, TASK-015
- Extensibility: TASK-016, TASK-017, TASK-018, TASK-019, TASK-020
- Migration scripts: TASK-022, TASK-023, TASK-024, TASK-026
- Documentation: TASK-030, TASK-031
- Testing: TASK-025 (execution)

### Human-Assigned Tasks (10 tasks)
- Infrastructure: TASK-001, TASK-002, TASK-003, TASK-004 (verification)
- Production ops: TASK-027, TASK-028, TASK-033, TASK-034, TASK-035
- Performance testing: TASK-029

### Collaborative Tasks (3 tasks)
- TASK-010: AI (config) + Human (setup)
- TASK-021: Human (install) + AI (template)
- TASK-032: Human (lead) + AI (support)

---

## 7. Quality Assurance

### Code Review Required (15 tasks)
TASK-005, TASK-006, TASK-009, TASK-011, TASK-014, TASK-015, TASK-016, TASK-017, TASK-018, TASK-019, TASK-020, TASK-022, TASK-023, TASK-024, TASK-026, TASK-031

### Testing Coverage Requirements
- Unit tests: >= 90% coverage for all new components (TASK-016 through TASK-020)
- Integration tests: TASK-025, TASK-026
- System tests: TASK-025
- Load tests: TASK-029

### Staging Validation Required
- TASK-023 (rollback script)
- TASK-028 (full migration)
- TASK-029 (performance)

---

## 8. Success Metrics

### Technical Metrics
- **M-1**: 100% data migration accuracy (verified in TASK-033)
- **M-2**: Downtime < 30 minutes (measured in TASK-033)
- **M-3**: Query performance 95th percentile < 200ms (validated in TASK-029, TASK-034)
- **M-4**: Error rate < 0.1% post-migration (monitored in TASK-034)
- **M-5**: All tests passing (verified in TASK-025, TASK-026)
- **M-9**: Rollback procedure < 10 minutes (tested in TASK-028)

### Operational Metrics
- **M-6**: Team training complete (achieved through TASK-030, TASK-031)
- **M-7**: No critical incidents in 7 days (tracked post-TASK-034)
- **M-8**: Backup success rate 100% (verified in TASK-032)

---

## 9. Communication Plan

### Stakeholder Updates
- **Week 1 End**: Infrastructure and configuration complete
- **Week 2 End**: Observability and extensibility framework complete
- **Week 3 End**: Staging migration successful
- **Week 4 Day 2**: Pre-deployment approval meeting
- **Week 4 Day 3**: Production migration execution (real-time updates)
- **Week 4 Day 4**: Post-migration status report

### Team Notifications
- Maintenance window announcement: T-7 days, T-3 days, T-1 day
- Migration start: T+0
- Migration progress: Every 15 minutes during execution
- Migration complete: T+100 minutes
- 24-hour stability report: T+24 hours

---

## 10. Rollback Triggers

Migration should be rolled back if any of the following occur during TASK-033:

1. **Data Verification Failure**: Row counts don't match between PostgreSQL and MySQL
2. **Time Overrun**: Migration exceeds 30-minute maintenance window
3. **Application Errors**: Critical errors during post-migration smoke tests
4. **Database Connection Failure**: Cannot establish stable connection to MySQL
5. **Schema Incompatibility**: Foreign key constraints or indexes fail to create
6. **Team Decision**: Migration team lead determines rollback necessary

**Rollback Procedure**: Execute TASK-023 (rollback script) immediately.

---

## 11. Post-Migration Tasks (Week 5-8)

These tasks are out of scope for initial implementation but should be tracked:

- **Week 5-8**: Monitor production stability
- **Week 8**: Decommission PostgreSQL instance (after 30-day retention period)
- **Week 8**: Archive migration documentation
- **Week 8**: Update disaster recovery procedures
- **Week 9**: Team retrospective and lessons learned

---

## 12. Contingency Plans

### If Staging Migration Fails (TASK-028)
- Do NOT proceed to production
- Investigate root cause
- Fix issues in migration scripts/configuration
- Re-run staging migration
- Only proceed to TASK-029 after successful staging migration

### If Performance Tests Fail (TASK-029)
- Identify slow queries
- Add missing indexes
- Optimize MySQL configuration
- Re-run performance tests
- Do NOT proceed to production if performance degrades significantly

### If Production Migration Fails (TASK-033)
- Execute rollback immediately (TASK-023)
- Conduct root cause analysis
- Fix issues identified
- Reschedule migration window
- Re-run staging migration with fixes

---

## 13. Definition of Done (Overall Project)

This project is considered complete when:

- [ ] All 35 tasks completed successfully
- [ ] Production running on MySQL 8 for 24 hours with no critical issues (TASK-034)
- [ ] All success metrics achieved (Section 8)
- [ ] Documentation complete and reviewed (TASK-031)
- [ ] Team trained on MySQL operations (TASK-030)
- [ ] PostgreSQL backup retention policy in place (TASK-035)
- [ ] Post-migration monitoring report published (TASK-034)
- [ ] Stakeholder sign-off received

---

**This task plan is ready for evaluation by planner-evaluators.**

**Estimated Total Effort**:
- AI tasks: ~45 hours
- Human tasks: ~35 hours
- Total: ~80 hours over 4 weeks (2 people, full-time equivalent)

**Critical Dependencies**:
- Staging environment must be ready by Week 2 Day 4
- Staging migration must succeed before production migration
- All tests must pass before production migration
- Pre-deployment checklist must be verified before production migration

**Success Probability**: High (based on thorough planning, staging validation, and rollback capability)
