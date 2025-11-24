# Design Document - MySQL 8 Database Unification

**Feature ID**: FEAT-DB-001
**Created**: 2025-11-24
**Last Updated**: 2025-11-24
**Designer**: designer agent

---

## Metadata

```yaml
design_metadata:
  feature_id: "FEAT-DB-001"
  feature_name: "MySQL 8 Database Unification"
  created: "2025-11-24"
  updated: "2025-11-24"
  iteration: 2
  priority: "high"
  estimated_effort: "medium"
```

---

## 1. Overview

### 1.1 Feature Summary

This feature unifies the database system across all environments (development, test, and production) to use MySQL 8.0+, eliminating the current inconsistency where production uses PostgreSQL while development and test environments use MySQL2.

**Current State:**
- Development: MySQL 5.5.8+ (mysql2 adapter)
- Test: MySQL 5.5.8+ (mysql2 adapter)
- Production: PostgreSQL (pg adapter)

**Target State:**
- Development: MySQL 8.0+
- Test: MySQL 8.0+
- Production: MySQL 8.0+

### 1.2 Goals and Objectives

1. **Eliminate environment parity issues**: Ensure all environments use identical database systems
2. **Reduce SQL compatibility risks**: Prevent PostgreSQL-specific SQL from breaking on MySQL environments
3. **Simplify development workflow**: Allow developers to catch production-related database issues earlier
4. **Standardize database operations**: Use consistent tooling, monitoring, and backup strategies
5. **Maintain zero data loss**: Safely migrate production data from PostgreSQL to MySQL 8

### 1.3 Success Criteria

- [ ] All environments successfully running on MySQL 8.0+
- [ ] 100% of production data migrated without loss
- [ ] All existing features working correctly on MySQL 8
- [ ] All RSpec tests passing on MySQL 8
- [ ] Production deployment completed with < 30 minutes of maintenance mode downtime (total migration time including preparation and monitoring: 2-3 hours)
- [ ] Rollback plan tested and ready
- [ ] Database performance metrics meeting or exceeding current baselines

---

## 2. Requirements Analysis

### 2.1 Functional Requirements

**FR-1: Database Configuration Update**
- Update `config/database.yml` to use mysql2 adapter for production
- Configure MySQL 8 connection parameters (host, port, username, password)
- Set appropriate connection pool size and timeout values
- Configure utf8mb4 encoding for full Unicode support

**FR-2: Dependency Management**
- Update `Gemfile` to use mysql2 gem in production environment
- Remove pg gem dependency
- Ensure mysql2 gem version is compatible with MySQL 8.0+

**FR-3: Data Migration**
- Export all data from PostgreSQL production database
- Transform data to MySQL-compatible format
- Import data into MySQL 8 production database
- Verify data integrity post-migration

**FR-4: Schema Migration**
- Ensure all ActiveRecord migrations are compatible with MySQL 8
- Update any PostgreSQL-specific data types or constraints
- Regenerate schema.rb from MySQL 8 database

**FR-5: Application Code Compatibility**
- Identify and update any PostgreSQL-specific SQL queries
- Update any database-specific features (e.g., full-text search, JSON operations)
- Ensure ActiveRecord queries work correctly with MySQL 8

### 2.2 Non-Functional Requirements

**NFR-1: Performance**
- Query performance should be equal to or better than current PostgreSQL setup
- Connection pool should handle current production load
- Index strategy optimized for MySQL 8

**NFR-2: Availability**
- Production downtime should not exceed 30 minutes during migration
- Rollback capability available if migration fails
- Database backup created before migration begins

**NFR-3: Data Integrity**
- Zero data loss during migration
- All foreign key relationships preserved
- All indexes and constraints maintained

**NFR-4: Security**
- MySQL 8 authentication using caching_sha2_password
- SSL/TLS connection encryption in production
- Principle of least privilege for database user permissions

**NFR-5: Maintainability**
- Clear documentation of migration process
- Standardized database configuration across environments
- Simplified backup and restore procedures

### 2.3 Constraints

**C-1: Technology Stack**
- Must use Rails 6.1.4 with ActiveRecord
- Ruby version: 3.0.2
- MySQL version: 8.0+ (latest LTS recommended)

**C-2: Deployment**
- Production environment constraints (hosting provider, resources)
- Need to coordinate with production deployment schedule
- Backup storage requirements for PostgreSQL data

**C-3: Backward Compatibility**
- Must maintain all existing application features
- Cannot break existing API contracts
- Must preserve all historical data

---

## 3. Architecture Design

### 3.1 Current Architecture

```
┌─────────────────────────────────────────────────┐
│                Rails Application                │
│                  (Rails 6.1.4)                  │
└─────────────┬───────────────────┬───────────────┘
              │                   │
              │                   │
    ┌─────────▼─────────┐  ┌──────▼──────────┐
    │  Development/Test │  │   Production    │
    │     MySQL 5.5+    │  │  PostgreSQL     │
    │   (mysql2 gem)    │  │    (pg gem)     │
    └───────────────────┘  └─────────────────┘
           ⚠️ INCONSISTENCY ⚠️
```

### 3.2 Target Architecture

```
┌─────────────────────────────────────────────────┐
│                Rails Application                │
│                  (Rails 6.1.4)                  │
└─────────────┬───────────────────┬───────────────┘
              │                   │
              │                   │
    ┌─────────▼─────────┐  ┌──────▼──────────┐
    │  Development/Test │  │   Production    │
    │     MySQL 8.0+    │  │   MySQL 8.0+    │
    │   (mysql2 gem)    │  │  (mysql2 gem)   │
    └───────────────────┘  └─────────────────┘
           ✅ CONSISTENT ✅
```

### 3.3 Component Breakdown

**3.3.1 Database Configuration Layer**
- `config/database.yml`: Unified configuration using mysql2 adapter
- Environment variables for credentials (DB_USERNAME, DB_PASSWORD, DB_HOST)
- Connection pooling configuration

**3.3.2 Application Layer**
- ActiveRecord models (no changes required if using standard AR queries)
- Custom SQL queries (may require updates)
- Database-specific features (full-text search, JSON columns)

**3.3.3 Migration Layer**
- Existing migrations (compatibility review required)
- Data migration scripts (PostgreSQL → MySQL 8)
- Schema generation

**3.3.4 Infrastructure Layer**
- Development: Local MySQL 8 installation
- Test: Local MySQL 8 installation
- Production: Cloud-hosted MySQL 8 instance

### 3.4 Data Flow

**Migration Data Flow:**

```
┌──────────────────┐
│   PostgreSQL     │
│    Production    │
└────────┬─────────┘
         │
         │ 1. Export
         │ (pg_dump)
         ▼
┌──────────────────┐
│  Migration Tool  │
│   - pgloader     │
│   - Custom ETL   │
└────────┬─────────┘
         │
         │ 2. Transform
         │ (Data type mapping)
         ▼
┌──────────────────┐
│   MySQL 8        │
│   Production     │
└──────────────────┘
         │
         │ 3. Verify
         │ (Data integrity checks)
         ▼
┌──────────────────┐
│   Application    │
│   Validation     │
└──────────────────┘
```

---

## 4. Data Model

### 4.1 Current Schema Analysis

Based on `db/schema.rb`, the application has the following tables:

1. **alarm_contents**
   - Fields: id, body (string), category (integer), timestamps
   - Indexes: unique index on body
   - Charset: utf8mb4

2. **contents**
   - Fields: id, body (string), category (integer), timestamps
   - Indexes: unique index on body
   - Charset: utf8mb4

3. **feedbacks**
   - Fields: id, text (text), timestamps
   - Charset: utf8mb4

4. **line_groups**
   - Fields: id, line_group_id (string), member_count, post_count, remind_at (date), set_span, status, timestamps
   - Indexes: unique index on line_group_id
   - Charset: utf8mb4

5. **operators**
   - Fields: id, email, crypted_password, salt, name, role, failed_logins_count, lock_expires_at, unlock_token, timestamps
   - Indexes: unique index on email, index on unlock_token
   - Charset: utf8mb4

### 4.2 PostgreSQL to MySQL 8 Data Type Mapping

| PostgreSQL Type | MySQL 8 Type | Notes |
|----------------|--------------|-------|
| integer | int | Direct mapping |
| varchar | varchar | Direct mapping |
| text | text | Direct mapping |
| timestamp without time zone | datetime | Precision may differ |
| date | date | Direct mapping |
| serial | int AUTO_INCREMENT | Rails handles this |

### 4.3 Compatibility Assessment

**Compatible Elements:**
- ✅ All current data types are standard SQL types
- ✅ UTF-8 encoding already configured (utf8mb4)
- ✅ No PostgreSQL-specific data types (e.g., hstore, array, jsonb)
- ✅ Standard indexes and constraints
- ✅ ActiveRecord migrations use database-agnostic syntax

**Potential Issues:**
- ⚠️ Timestamp precision differences (PostgreSQL vs MySQL)
- ⚠️ Case sensitivity in string comparisons (collation)
- ⚠️ Default value handling for datetime fields

### 4.4 Schema Migration Strategy

1. **Review all migrations** for database-specific syntax
2. **Test migrations** on clean MySQL 8 database
3. **Update schema.rb** to reflect MySQL 8 structure
4. **Verify constraints** and indexes are properly created

---

## 5. Configuration Design

### 5.1 Updated database.yml

```yaml
default: &default
  adapter: mysql2
  encoding: utf8mb4
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch("DB_USERNAME", "root") %>
  password: <%= ENV.fetch("DB_PASSWORD", nil) %>
  host: <%= ENV.fetch("DB_HOST", "localhost") %>
  port: <%= ENV.fetch("DB_PORT", 3306) %>

development:
  <<: *default
  database: reline_development

test:
  <<: *default
  database: reline_test

production:
  <<: *default
  database: <%= ENV.fetch("DB_NAME", "reline_production") %>
  # Production-specific settings
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 10 } %>
  timeout: 5000
  reconnect: true
  # SSL configuration for production
  sslca: <%= ENV['DB_SSL_CA'] %>
  sslkey: <%= ENV['DB_SSL_KEY'] %>
  sslcert: <%= ENV['DB_SSL_CERT'] %>
```

### 5.2 Updated Gemfile

```ruby
# Database
gem 'mysql2', '~> 0.5'

# Remove production-specific pg gem
# group :production do
#   gem 'pg'
# end
```

### 5.3 Environment Variables (Production)

```bash
# Database connection
DB_HOST=your-mysql-host.com
DB_PORT=3306
DB_NAME=reline_production
DB_USERNAME=reline_app
DB_PASSWORD=secure_password_here

# SSL/TLS (optional but recommended)
DB_SSL_CA=/etc/mysql/certs/ca-cert.pem
DB_SSL_KEY=/etc/mysql/certs/client-key.pem
DB_SSL_CERT=/etc/mysql/certs/client-cert.pem

# Rails settings
RAILS_MAX_THREADS=10
```

---

## 6. Migration Strategy

### 6.1 Migration Approach

We will use a **Multi-Phase Migration** approach to minimize risk and downtime:

**Phase 1: Preparation (No Downtime)**
- Set up MySQL 8 instance in production environment
- Configure database users and permissions
- Test connectivity from application server

**Phase 2: Data Migration (Maintenance Window)**
- Enable maintenance mode (put up maintenance page)
- Create final PostgreSQL backup
- Migrate data from PostgreSQL to MySQL 8
- Verify data integrity
- Update application configuration
- Restart application with MySQL 8
- Run smoke tests
- Disable maintenance mode

**Phase 3: Post-Migration (Monitoring)**
- Monitor application performance
- Monitor database performance
- Keep PostgreSQL backup for 30 days
- Document any issues and resolutions

### 6.2 Migration Tools

**Option 1: pgloader (Recommended)**
- Automated migration from PostgreSQL to MySQL
- Handles data type conversions
- Fast and reliable

**Option 2: Custom ETL Script**
- Ruby-based migration script
- More control over data transformation
- Can validate data during migration

**Option 3: Dump and Load**
- pg_dump to export PostgreSQL data
- Transform SQL to MySQL-compatible format
- mysql command-line to import

### 6.3 Detailed Migration Steps

**Step 1: Pre-Migration Preparation**
```bash
# 1. Create PostgreSQL backup
pg_dump -h $PG_HOST -U $PG_USER -d reline_production > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Verify backup
psql -h $PG_HOST -U $PG_USER -d reline_production_test < backup_*.sql

# 3. Set up MySQL 8 instance
mysql -h $MYSQL_HOST -u root -p -e "CREATE DATABASE reline_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 4. Create application user
mysql -h $MYSQL_HOST -u root -p -e "CREATE USER 'reline_app'@'%' IDENTIFIED BY 'password';"
mysql -h $MYSQL_HOST -u root -p -e "GRANT ALL PRIVILEGES ON reline_production.* TO 'reline_app'@'%';"
mysql -h $MYSQL_HOST -u root -p -e "FLUSH PRIVILEGES;"
```

**Step 2: Data Migration (Using pgloader)**
```bash
# 1. Install pgloader (if not already installed)
# Ubuntu: apt-get install pgloader
# macOS: brew install pgloader

# 2. Create pgloader configuration
cat > migration.load <<EOF
LOAD DATABASE
     FROM postgresql://$PG_USER:$PG_PASSWORD@$PG_HOST/$PG_DATABASE
     INTO mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST/$MYSQL_DATABASE

WITH include drop, create tables, create indexes, reset sequences,
     workers = 8, concurrency = 1,
     multiple readers per thread, rows per range = 50000

SET MySQL PARAMETERS
    net_read_timeout  = '120',
    net_write_timeout = '120'

CAST type datetime to datetime drop default drop not null using zero-dates-to-null,
     type timestamp to datetime drop default drop not null using zero-dates-to-null

BEFORE LOAD DO
     \$\$ ALTER DATABASE reline_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \$\$;
EOF

# 3. Run migration
pgloader migration.load
```

**Step 3: Post-Migration Verification**
```ruby
# Create verification script: verify_migration.rb
require 'pg'
require 'mysql2'

pg_conn = PG.connect(host: ENV['PG_HOST'], dbname: 'reline_production', user: ENV['PG_USER'], password: ENV['PG_PASSWORD'])
mysql_conn = Mysql2::Client.new(host: ENV['MYSQL_HOST'], database: 'reline_production', username: ENV['MYSQL_USER'], password: ENV['MYSQL_PASSWORD'])

tables = ['alarm_contents', 'contents', 'feedbacks', 'line_groups', 'operators']

tables.each do |table|
  pg_count = pg_conn.exec("SELECT COUNT(*) FROM #{table}").first['count'].to_i
  mysql_count = mysql_conn.query("SELECT COUNT(*) FROM #{table}").first['count(*)']

  if pg_count == mysql_count
    puts "✅ #{table}: #{mysql_count} rows (match)"
  else
    puts "❌ #{table}: PG=#{pg_count}, MySQL=#{mysql_count} (MISMATCH)"
  end
end

pg_conn.close
mysql_conn.close
```

**Step 4: Application Configuration Update**
```bash
# 1. Update database.yml (already done in design)

# 2. Update Gemfile (already done in design)

# 3. Bundle install
bundle install --deployment --without development test

# 4. Verify database connection
RAILS_ENV=production bundle exec rails db:version

# 5. Run database migrations (to ensure schema is up-to-date)
RAILS_ENV=production bundle exec rails db:migrate

# 6. Restart application
systemctl restart reline-app  # or your deployment method
```

### 6.4 Rollback Plan

If migration fails or issues are discovered:

**Immediate Rollback (During Maintenance Window):**
```bash
# 1. Stop application
systemctl stop reline-app

# 2. Revert database.yml to PostgreSQL configuration
git checkout config/database.yml

# 3. Revert Gemfile
git checkout Gemfile
bundle install --deployment

# 4. Restart application with PostgreSQL
systemctl start reline-app

# 5. Verify application is working
curl http://localhost/health
```

**Post-Deployment Rollback (After Maintenance Window):**
1. Enable maintenance mode
2. Follow immediate rollback steps above
3. Investigate issues in MySQL setup
4. Schedule new migration window
5. Disable maintenance mode

---

## 7. Security Considerations

### 7.1 Threat Model

**T-1: Database Credential Exposure**
- **Risk**: Production database credentials leaked
- **Impact**: Unauthorized access to production data
- **Likelihood**: Low (if following best practices)

**T-2: SQL Injection**
- **Risk**: Different SQL syntax between PostgreSQL and MySQL could expose new injection vectors
- **Impact**: Data breach or corruption
- **Likelihood**: Low (using ActiveRecord parameterized queries)

**T-3: Man-in-the-Middle Attack**
- **Risk**: Unencrypted database connection intercepted
- **Impact**: Credential theft, data exposure
- **Likelihood**: Medium (if not using SSL/TLS)

**T-4: Weak Authentication**
- **Risk**: MySQL default authentication plugin vulnerabilities
- **Impact**: Unauthorized database access
- **Likelihood**: Low (using caching_sha2_password)

**T-5: Data Migration Corruption**
- **Risk**: Data corruption during migration process
- **Impact**: Data loss or integrity issues
- **Likelihood**: Medium (complex migration process)

### 7.2 Security Controls

**SC-1: Credential Management**
- Store database credentials in environment variables only
- Never commit credentials to version control
- Use different credentials for each environment
- Rotate production credentials after migration

**SC-2: Connection Security**
- Enable SSL/TLS for production database connections
- Use certificate-based authentication where possible
- Configure firewall rules to restrict database access to application servers only

**SC-3: Authentication**
- Use MySQL 8's caching_sha2_password authentication plugin
- Enforce strong password policy (16+ characters, complexity requirements)
- Implement principle of least privilege for database users

**SC-4: Data Protection**
- Create encrypted backups of PostgreSQL data before migration
- Use encrypted storage for backup files
- Implement backup retention policy (30 days)

**SC-5: Access Control**
- Create application-specific database user (not root)
- Grant only necessary privileges (SELECT, INSERT, UPDATE, DELETE)
- Revoke unnecessary privileges (CREATE, DROP, ALTER for production user)

**SC-6: Audit Logging**
- Enable MySQL general query log during migration (temporary)
- Monitor failed authentication attempts
- Log all schema changes

**SC-7: Code Review and Query Auditing**
- Review all SQL queries for proper parameterization
- Audit ActiveRecord queries for SQL injection vulnerabilities
- Implement automated SQL injection testing in test suite
- Code review checklist for database query changes

### 7.3 Security Configuration

**MySQL 8 Production User Setup:**
```sql
-- Create application user with strong password
CREATE USER 'reline_app'@'%'
  IDENTIFIED WITH caching_sha2_password BY 'strong_password_here'
  REQUIRE SSL;

-- Grant necessary privileges only
GRANT SELECT, INSERT, UPDATE, DELETE ON reline_production.* TO 'reline_app'@'%';

-- Do NOT grant: CREATE, DROP, ALTER, INDEX, REFERENCES
-- These should only be available to migration user

-- Create separate migration user for schema changes
CREATE USER 'reline_migrate'@'%'
  IDENTIFIED WITH caching_sha2_password BY 'different_strong_password'
  REQUIRE SSL;

GRANT ALL PRIVILEGES ON reline_production.* TO 'reline_migrate'@'%';

FLUSH PRIVILEGES;
```

**SSL/TLS Configuration:**
```bash
# Generate SSL certificates (if using self-signed)
openssl req -newkey rsa:2048 -nodes -keyout /etc/mysql/certs/client-key.pem -x509 -days 365 -out /etc/mysql/certs/client-cert.pem

# Configure MySQL server (my.cnf)
[mysqld]
require_secure_transport=ON
ssl-ca=/etc/mysql/certs/ca-cert.pem
ssl-cert=/etc/mysql/certs/server-cert.pem
ssl-key=/etc/mysql/certs/server-key.pem
```

---

## 8. Error Handling

### 8.1 Error Scenarios

**E-1: Migration Data Mismatch**
- **Scenario**: Row counts don't match between PostgreSQL and MySQL after migration
- **Detection**: Verification script reports count mismatch
- **Recovery**: Re-run migration with verbose logging, investigate missing/duplicate rows

**E-2: Connection Failure**
- **Scenario**: Application cannot connect to MySQL 8 after configuration update
- **Detection**: Rails logs show connection errors
- **Recovery**: Verify credentials, network connectivity, firewall rules; rollback if necessary

**E-3: Schema Incompatibility**
- **Scenario**: Migration creates tables with incompatible schema
- **Detection**: Foreign key constraints fail, indexes missing
- **Recovery**: Manually fix schema issues, re-run migrations

**E-4: Performance Degradation** (See R-3 mitigation strategies in Section 12.2)
- **Scenario**: Queries run significantly slower on MySQL 8 than PostgreSQL
- **Detection**: Application monitoring shows increased response times
- **Recovery**: Add missing indexes, optimize queries, adjust MySQL configuration

**E-5: Data Type Conversion Issues**
- **Scenario**: Data loss or corruption during type conversion (e.g., timestamp precision)
- **Detection**: Data validation fails, application errors
- **Recovery**: Rollback, fix conversion rules, re-migrate

**E-6: Character Encoding Issues**
- **Scenario**: Unicode characters corrupted during migration
- **Detection**: UI displays garbled text
- **Recovery**: Verify utf8mb4 configuration, re-migrate with correct encoding

### 8.2 Error Messages

**Application-Level Errors:**
```ruby
# config/initializers/database_error_handler.rb
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    if conn.adapter_name != 'Mysql2'
      Rails.logger.error "❌ Expected Mysql2 adapter, got #{conn.adapter_name}"
      raise "Database adapter mismatch. Expected Mysql2, got #{conn.adapter_name}"
    end
  end
end
```

**Migration Script Errors:**
```ruby
# Error handling in migration verification script
begin
  mysql_conn = Mysql2::Client.new(
    host: ENV['MYSQL_HOST'],
    database: 'reline_production',
    username: ENV['MYSQL_USER'],
    password: ENV['MYSQL_PASSWORD']
  )
rescue Mysql2::Error => e
  puts "❌ MySQL connection failed: #{e.message}"
  puts "   - Verify MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD environment variables"
  puts "   - Check network connectivity and firewall rules"
  puts "   - Verify MySQL server is running"
  exit 1
end
```

### 8.3 Recovery Strategies

**RS-1: Automated Rollback**
```bash
#!/bin/bash
# rollback_to_postgresql.sh

echo "🔄 Starting rollback to PostgreSQL..."

# Stop application
systemctl stop reline-app

# Restore PostgreSQL configuration
git checkout config/database.yml Gemfile Gemfile.lock
bundle install --deployment

# Verify PostgreSQL connection
RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name"

# Restart application
systemctl start reline-app

echo "✅ Rollback complete. Application running on PostgreSQL."
```

**RS-2: Data Re-Migration**
- Keep PostgreSQL instance running for 30 days after migration
- If data issues found, re-run migration with corrected parameters
- Use transaction-based migration where possible

**RS-3: Partial Migration**
- Migrate read-only tables first
- Test application with mixed database setup
- Gradually migrate remaining tables

---

## 9. Testing Strategy

### 9.1 Unit Testing

**Pre-Migration Testing:**
```ruby
# spec/support/database_adapter_spec.rb
RSpec.describe 'Database Adapter' do
  it 'uses mysql2 adapter in all environments' do
    expect(ActiveRecord::Base.connection.adapter_name).to eq('Mysql2')
  end

  it 'uses utf8mb4 encoding' do
    encoding = ActiveRecord::Base.connection.execute('SHOW VARIABLES LIKE "character_set_database"').first[1]
    expect(encoding).to eq('utf8mb4')
  end

  it 'uses utf8mb4_unicode_ci collation' do
    collation = ActiveRecord::Base.connection.execute('SHOW VARIABLES LIKE "collation_database"').first[1]
    expect(collation).to eq('utf8mb4_unicode_ci')
  end
end
```

**Model-Level Testing:**
```ruby
# Run full RSpec suite on MySQL 8
bundle exec rspec

# Verify no PostgreSQL-specific code
bundle exec rspec --tag ~postgresql
```

### 9.2 Integration Testing

**Database Migration Testing:**
```ruby
# spec/integration/migration_spec.rb
RSpec.describe 'Database Migration' do
  it 'successfully migrates all tables' do
    # Test on staging environment with PostgreSQL → MySQL migration
    expect { run_migration_script }.not_to raise_error
  end

  it 'preserves all data integrity' do
    # Verify row counts match
    # Verify foreign key relationships intact
    # Verify unique constraints maintained
  end

  it 'maintains all indexes' do
    indexes = ActiveRecord::Base.connection.indexes(:line_groups)
    expect(indexes.map(&:name)).to include('index_line_groups_on_line_group_id')
  end
end
```

**System Testing:**
```ruby
# Run full system test suite
bundle exec rspec spec/system

# Verify critical user flows:
# - Operator login/logout
# - LINE group registration
# - Content creation
# - Feedback submission
# - Alarm content management
```

### 9.3 Edge Cases to Test

**TC-1: Timestamp Precision**
```ruby
# Test timestamp precision differences
RSpec.describe 'Timestamp Precision' do
  it 'preserves timestamp precision to microseconds' do
    time = Time.zone.now
    operator = Operator.create!(email: 'test@example.com', name: 'Test', password: 'password')
    operator.reload

    # MySQL stores up to microsecond precision
    expect(operator.created_at.usec).to be_within(1000).of(time.usec)
  end
end
```

**TC-2: Unicode Handling**
```ruby
# Test utf8mb4 support (4-byte characters)
RSpec.describe 'Unicode Support' do
  it 'supports emoji and 4-byte UTF-8 characters' do
    content = Content.create!(body: 'Test with emoji 🐱😺', category: 0)
    content.reload

    expect(content.body).to eq('Test with emoji 🐱😺')
  end
end
```

**TC-3: Case Sensitivity**
```ruby
# Test collation case sensitivity
RSpec.describe 'Collation Case Sensitivity' do
  it 'performs case-insensitive comparisons' do
    Operator.create!(email: 'Test@Example.com', name: 'Test', password: 'password')

    # utf8mb4_unicode_ci is case-insensitive
    expect(Operator.find_by(email: 'test@example.com')).to be_present
  end
end
```

**TC-4: Large Text Fields**
```ruby
# Test text field limits
RSpec.describe 'Text Field Limits' do
  it 'handles large text fields (up to 65535 bytes)' do
    large_text = 'A' * 60000
    feedback = Feedback.create!(text: large_text)
    feedback.reload

    expect(feedback.text.length).to eq(60000)
  end
end
```

**TC-5: Concurrent Writes**
```ruby
# Test locking and concurrency
RSpec.describe 'Concurrent Updates' do
  it 'handles concurrent updates with optimistic locking' do
    line_group = LineGroup.create!(line_group_id: 'test123', remind_at: Date.today)

    # Simulate concurrent updates
    threads = 2.times.map do
      Thread.new do
        lg = LineGroup.find(line_group.id)
        lg.update!(post_count: lg.post_count + 1)
      end
    end

    threads.each(&:join)
    line_group.reload

    expect(line_group.post_count).to eq(2)
  end
end
```

### 9.4 Performance Testing

**Load Testing:**
```bash
# Use Apache Bench for basic load testing
ab -n 1000 -c 10 http://localhost:3000/

# Monitor MySQL performance
mysql -e "SHOW FULL PROCESSLIST;"
mysql -e "SHOW ENGINE INNODB STATUS\G"
```

**Query Performance:**
```ruby
# spec/performance/query_performance_spec.rb
RSpec.describe 'Query Performance' do
  it 'performs index scans on unique lookups' do
    explain = LineGroup.where(line_group_id: 'test123').explain
    expect(explain).to include('key: index_line_groups_on_line_group_id')
  end

  it 'completes complex queries within acceptable time' do
    expect {
      # Complex query
      Operator.joins(:line_groups).where(role: :admin).count
    }.to perform_under(100).ms
  end
end
```

### 9.5 Staging Environment Testing

**Prerequisites:**
1. Set up staging environment identical to production
2. Copy production data to staging (anonymized if necessary)
3. Perform full migration on staging

**Test Plan:**
1. Run migration script on staging PostgreSQL → MySQL 8
2. Verify data integrity (row counts, checksums)
3. Run full RSpec test suite
4. Perform manual smoke testing of critical features
5. Load test with production-like traffic
6. Monitor for 24 hours before production migration

---

## 10. Observability and Monitoring

### 10.1 Structured Logging Strategy

**10.1.1 Semantic Logger with JSON Format**

```ruby
# config/initializers/semantic_logger.rb
require 'semantic_logger'

# Configure Semantic Logger for structured logging
SemanticLogger.default_level = :info
SemanticLogger.add_appender(io: $stdout, formatter: :json)

# Add migration-specific logger
module DatabaseMigration
  class Logger
    include SemanticLogger::Loggable

    def log_migration_start(source:, target:, strategy:)
      logger.info(
        message: 'Database migration started',
        source_adapter: source,
        target_adapter: target,
        migration_strategy: strategy,
        timestamp: Time.current.iso8601
      )
    end

    def log_table_migration(table:, row_count:, duration_ms:)
      logger.info(
        message: 'Table migration completed',
        table_name: table,
        rows_migrated: row_count,
        duration_ms: duration_ms,
        timestamp: Time.current.iso8601
      )
    end

    def log_migration_error(error:, context:)
      logger.error(
        message: 'Migration error occurred',
        error_class: error.class.name,
        error_message: error.message,
        context: context,
        backtrace: error.backtrace&.first(5),
        timestamp: Time.current.iso8601
      )
    end
  end
end
```

**10.1.2 Centralized Log Aggregation**

```yaml
# config/logging.yml
production:
  appenders:
    - type: stdout
      formatter: json
    - type: file
      path: /var/log/reline/production.log
      formatter: json
      rotation:
        max_size: 100MB
        max_files: 10
    - type: syslog
      host: <%= ENV['LOG_AGGREGATOR_HOST'] %>
      port: <%= ENV.fetch('LOG_AGGREGATOR_PORT', 514) %>
      formatter: json

  log_levels:
    default: info
    database_migration: debug
    active_record: info
```

**10.1.3 Migration-Specific Logging**

```ruby
# lib/database_migration/logging.rb
module DatabaseMigration
  module Logging
    def self.configure
      # Create separate log file for migration events
      migration_logger = SemanticLogger['DatabaseMigration']
      migration_logger.add_appender(
        file_name: '/var/log/reline/migration.log',
        formatter: :json
      )
    end

    def self.log_verification(results:)
      SemanticLogger['DatabaseMigration'].info(
        message: 'Data verification completed',
        tables_verified: results.count,
        total_rows: results.sum { |r| r[:target_count] },
        all_matched: results.all? { |r| r[:match] },
        mismatches: results.reject { |r| r[:match] },
        timestamp: Time.current.iso8601
      )
    end
  end
end
```

### 10.2 Automated Monitoring and Alerting

**10.2.1 Prometheus Metrics Exporter**

```ruby
# config/initializers/prometheus.rb
require 'prometheus/client'

module DatabaseMetrics
  def self.setup
    prometheus = Prometheus::Client.registry

    # Database connection pool metrics
    @pool_size = prometheus.gauge(
      :database_pool_size,
      docstring: 'Current database connection pool size'
    )

    @pool_available = prometheus.gauge(
      :database_pool_available,
      docstring: 'Available connections in pool'
    )

    @pool_waiting = prometheus.gauge(
      :database_pool_waiting,
      docstring: 'Threads waiting for database connection'
    )

    # Query performance metrics
    @query_duration = prometheus.histogram(
      :database_query_duration_seconds,
      docstring: 'Database query execution time',
      labels: [:query_type, :table],
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0]
    )

    # Migration metrics
    @migration_progress = prometheus.gauge(
      :migration_progress_percent,
      docstring: 'Migration progress percentage',
      labels: [:table]
    )

    @migration_errors = prometheus.counter(
      :migration_errors_total,
      docstring: 'Total migration errors',
      labels: [:error_type]
    )
  end

  def self.record_query(type:, table:, duration:)
    @query_duration.observe(duration, labels: { query_type: type, table: table })
  end

  def self.update_pool_metrics
    pool = ActiveRecord::Base.connection_pool
    @pool_size.set(pool.size)
    @pool_available.set(pool.connections.count { |c| !c.in_use? })
    @pool_waiting.set(pool.instance_variable_get(:@available).num_waiting)
  end
end

# Periodic metrics update
Thread.new do
  loop do
    DatabaseMetrics.update_pool_metrics
    sleep 10
  end
end
```

**10.2.2 Grafana Dashboard Configuration**

```json
{
  "dashboard": {
    "title": "MySQL 8 Migration Monitoring",
    "panels": [
      {
        "title": "Database Connection Pool",
        "targets": [
          {
            "expr": "database_pool_size",
            "legendFormat": "Pool Size"
          },
          {
            "expr": "database_pool_available",
            "legendFormat": "Available Connections"
          }
        ]
      },
      {
        "title": "Query Performance (95th Percentile)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, database_query_duration_seconds_bucket)",
            "legendFormat": "95th Percentile"
          }
        ]
      },
      {
        "title": "Migration Progress",
        "targets": [
          {
            "expr": "migration_progress_percent",
            "legendFormat": "{{table}}"
          }
        ]
      }
    ]
  }
}
```

**10.2.3 Alerting Rules**

```yaml
# config/alerting_rules.yml
groups:
  - name: database_migration
    interval: 30s
    rules:
      - alert: HighDatabaseConnectionPoolUsage
        expr: database_pool_available / database_pool_size < 0.2
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Database connection pool usage above 80%"
          description: "Only {{ $value | humanizePercentage }} of connections available"

      - alert: SlowDatabaseQueries
        expr: histogram_quantile(0.95, database_query_duration_seconds_bucket) > 0.2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database queries are slow (95th percentile > 200ms)"

      - alert: MigrationErrors
        expr: increase(migration_errors_total[5m]) > 0
        labels:
          severity: critical
        annotations:
          summary: "Migration errors detected"
          description: "{{ $value }} migration errors in the last 5 minutes"

      - alert: DatabaseConnectionFailure
        expr: up{job="mysql"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Cannot connect to MySQL database"
```

### 10.3 Migration Progress Tracking

**10.3.1 Progress Dashboard**

```ruby
# lib/database_migration/progress_tracker.rb
module DatabaseMigration
  class ProgressTracker
    def initialize(tables:)
      @tables = tables
      @progress = {}
      tables.each { |table| @progress[table] = { completed: 0, total: 0 } }
    end

    def update_progress(table:, completed:, total:)
      @progress[table] = { completed: completed, total: total }
      percentage = (completed.to_f / total * 100).round(2)

      # Update Prometheus metric
      DatabaseMetrics.migration_progress.set(
        percentage,
        labels: { table: table }
      )

      # Log progress
      SemanticLogger['DatabaseMigration'].info(
        message: 'Migration progress update',
        table: table,
        completed: completed,
        total: total,
        percentage: percentage
      )
    end

    def overall_progress
      total_completed = @progress.values.sum { |p| p[:completed] }
      total_rows = @progress.values.sum { |p| p[:total] }
      (total_completed.to_f / total_rows * 100).round(2)
    end

    def to_json
      {
        tables: @progress,
        overall: overall_progress,
        timestamp: Time.current.iso8601
      }
    end
  end
end
```

**10.3.2 Web-Based Progress Viewer**

```ruby
# app/controllers/admin/migration_status_controller.rb
module Admin
  class MigrationStatusController < ApplicationController
    before_action :require_admin

    def show
      progress_file = Rails.root.join('tmp/migration_progress.json')
      if File.exist?(progress_file)
        @progress = JSON.parse(File.read(progress_file))
      else
        @progress = { status: 'not_started' }
      end

      render json: @progress
    end
  end
end
```

### 10.4 Distributed Tracing with OpenTelemetry

```ruby
# config/initializers/opentelemetry.rb
require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/all'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'reline-app'
  c.service_version = '1.0.0'

  # Add instrumentation for ActiveRecord
  c.use 'OpenTelemetry::Instrumentation::ActiveRecord'
  c.use 'OpenTelemetry::Instrumentation::Rails'
end

# Custom tracing for migration operations
module DatabaseMigration
  module Tracing
    def self.trace_migration(operation:)
      tracer = OpenTelemetry.tracer_provider.tracer('database_migration')

      tracer.in_span(operation) do |span|
        span.set_attribute('migration.operation', operation)
        span.set_attribute('migration.timestamp', Time.current.iso8601)

        begin
          result = yield
          span.set_attribute('migration.status', 'success')
          result
        rescue => e
          span.set_attribute('migration.status', 'error')
          span.set_attribute('migration.error', e.message)
          span.record_exception(e)
          raise
        end
      end
    end
  end
end
```

### 10.5 Enhanced Health Check Endpoints

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      database: database_status,
      timestamp: Time.current.iso8601
    }
  end

  def migration_status
    render json: {
      migration_in_progress: migration_in_progress?,
      current_database: current_database_info,
      health_checks: run_health_checks
    }
  end

  private

  def database_status
    {
      adapter: ActiveRecord::Base.connection.adapter_name,
      version: ActiveRecord::Base.connection.select_value('SELECT VERSION()'),
      pool_size: ActiveRecord::Base.connection_pool.size,
      active_connections: ActiveRecord::Base.connection_pool.connections.count { |c| c.in_use? }
    }
  rescue => e
    { status: 'error', message: e.message }
  end

  def migration_in_progress?
    File.exist?(Rails.root.join('tmp/migration_in_progress'))
  end

  def current_database_info
    {
      adapter: ActiveRecord::Base.connection.adapter_name,
      database: ActiveRecord::Base.connection.current_database,
      host: ActiveRecord::Base.connection_config[:host]
    }
  end

  def run_health_checks
    {
      database_reachable: database_reachable?,
      migrations_current: migrations_current?,
      sample_query_works: sample_query_works?
    }
  end

  def database_reachable?
    ActiveRecord::Base.connection.active?
  rescue
    false
  end

  def migrations_current?
    ActiveRecord::Migration.check_pending!
    true
  rescue
    false
  end

  def sample_query_works?
    Operator.limit(1).count
    true
  rescue
    false
  end
end

# config/routes.rb
get '/health', to: 'health#show'
get '/health/migration', to: 'health#migration_status'
```

### 10.6 Log Retention Policy

```yaml
# config/log_retention.yml
production:
  migration_logs:
    path: /var/log/reline/migration.log
    retention_days: 90
    rotation:
      max_size: 500MB
      max_files: 20

  application_logs:
    path: /var/log/reline/production.log
    retention_days: 30
    rotation:
      max_size: 100MB
      max_files: 10

  audit_logs:
    path: /var/log/reline/audit.log
    retention_days: 365
    rotation:
      max_size: 1GB
      max_files: 50
```

```bash
# scripts/log_cleanup.sh
#!/bin/bash
# Automated log cleanup based on retention policy

CONFIG_FILE="config/log_retention.yml"

# Parse YAML and clean up old logs
# Migration logs: 90 days
find /var/log/reline/migration*.log -mtime +90 -delete

# Application logs: 30 days
find /var/log/reline/production*.log -mtime +30 -delete

# Audit logs: 365 days
find /var/log/reline/audit*.log -mtime +365 -delete

echo "Log cleanup completed at $(date)"
```

---

## 11. Extensibility and Reusability

### 11.1 Database Adapter Abstraction Layer

**11.1.1 Adapter Interface**

```ruby
# lib/database_adapter/base.rb
module DatabaseAdapter
  class Base
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def adapter_name
      raise NotImplementedError, "#{self.class} must implement adapter_name"
    end

    def migrate_from(source_adapter, options = {})
      raise NotImplementedError, "#{self.class} must implement migrate_from"
    end

    def verify_compatibility
      raise NotImplementedError, "#{self.class} must implement verify_compatibility"
    end

    def connection_params
      raise NotImplementedError, "#{self.class} must implement connection_params"
    end

    def version_info
      {
        adapter: adapter_name,
        version: database_version,
        supported: version_supported?
      }
    end

    protected

    def database_version
      raise NotImplementedError
    end

    def version_supported?
      raise NotImplementedError
    end
  end
end
```

**11.1.2 MySQL 8 Adapter Implementation**

```ruby
# lib/database_adapter/mysql8_adapter.rb
module DatabaseAdapter
  class MySQL8Adapter < Base
    MINIMUM_VERSION = '8.0.0'
    RECOMMENDED_VERSION = '8.0.34'

    def adapter_name
      'mysql2'
    end

    def migrate_from(source_adapter, options = {})
      case source_adapter
      when PostgreSQLAdapter
        PostgreSQLToMySQL8Migrator.new(@config, options).migrate
      when MySQL57Adapter
        MySQL57ToMySQL8Migrator.new(@config, options).migrate
      else
        raise "Unsupported migration path from #{source_adapter.class}"
      end
    end

    def verify_compatibility
      checks = {
        version_check: version_supported?,
        encoding_check: encoding_compatible?,
        features_check: required_features_available?
      }

      unless checks.values.all?
        raise CompatibilityError, "Compatibility checks failed: #{checks}"
      end

      checks
    end

    def connection_params
      {
        adapter: 'mysql2',
        encoding: 'utf8mb4',
        collation: 'utf8mb4_unicode_ci',
        pool: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
        timeout: 5000,
        reconnect: true
      }
    end

    protected

    def database_version
      ActiveRecord::Base.connection.select_value('SELECT VERSION()')
    end

    def version_supported?
      Gem::Version.new(database_version.split('-').first) >= Gem::Version.new(MINIMUM_VERSION)
    end

    def encoding_compatible?
      encoding = ActiveRecord::Base.connection.select_value(
        "SHOW VARIABLES LIKE 'character_set_database'"
      )
      encoding == 'utf8mb4'
    end

    def required_features_available?
      # Check for caching_sha2_password support
      plugins = ActiveRecord::Base.connection.select_values(
        "SELECT PLUGIN_NAME FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_NAME = 'caching_sha2_password'"
      )
      plugins.include?('caching_sha2_password')
    end
  end
end
```

**11.1.3 PostgreSQL Adapter Implementation**

```ruby
# lib/database_adapter/postgresql_adapter.rb
module DatabaseAdapter
  class PostgreSQLAdapter < Base
    def adapter_name
      'postgresql'
    end

    def connection_params
      {
        adapter: 'postgresql',
        encoding: 'unicode',
        pool: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
        timeout: 5000
      }
    end

    protected

    def database_version
      ActiveRecord::Base.connection.select_value('SELECT VERSION()')
    end

    def version_supported?
      # PostgreSQL version checking logic
      true
    end
  end
end
```

**11.1.4 Adapter Factory**

```ruby
# lib/database_adapter/factory.rb
module DatabaseAdapter
  class Factory
    def self.create(adapter_type, config = {})
      case adapter_type.to_s.downcase
      when 'mysql2', 'mysql8'
        MySQL8Adapter.new(config)
      when 'postgresql', 'pg'
        PostgreSQLAdapter.new(config)
      when 'mysql57'
        MySQL57Adapter.new(config)
      else
        raise "Unsupported adapter type: #{adapter_type}"
      end
    end

    def self.current_adapter
      adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
      create(adapter_name)
    end
  end
end
```

### 11.2 Migration Strategy Framework

**11.2.1 Generic Migration Framework**

```ruby
# lib/database_migration/framework.rb
module DatabaseMigration
  class Framework
    attr_reader :source, :target, :strategy, :config

    def initialize(source:, target:, strategy: nil, config: {})
      @source = DatabaseAdapter::Factory.create(source)
      @target = DatabaseAdapter::Factory.create(target, config)
      @strategy = strategy || infer_strategy
      @config = MigrationConfig.new(config)
    end

    def execute
      Tracing.trace_migration(operation: 'full_migration') do
        validate_prerequisites
        prepare
        migrate
        verify
        cleanup
      end
    end

    def validate_prerequisites
      @source.verify_compatibility
      @target.verify_compatibility
    end

    def prepare
      Logger.new.log_migration_start(
        source: @source.adapter_name,
        target: @target.adapter_name,
        strategy: @strategy.class.name
      )

      @strategy.prepare(@source, @target)
    end

    def migrate
      @strategy.migrate(@source, @target)
    end

    def verify
      verifier = Verifier.new(@source, @target)
      results = verifier.verify_all

      unless results[:all_matched]
        raise MigrationError, "Verification failed: #{results[:mismatches]}"
      end

      Logging.log_verification(results: results[:table_results])
      results
    end

    def cleanup
      @strategy.cleanup
    end

    private

    def infer_strategy
      StrategyFactory.create(
        source: @source.adapter_name,
        target: @target.adapter_name,
        config: @config
      )
    end
  end
end
```

**11.2.2 Migration Strategy Interface**

```ruby
# lib/database_migration/strategies/base.rb
module DatabaseMigration
  module Strategies
    class Base
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      def prepare(source, target)
        raise NotImplementedError, "#{self.class} must implement prepare"
      end

      def migrate(source, target)
        raise NotImplementedError, "#{self.class} must implement migrate"
      end

      def cleanup
        # Default: no cleanup needed
      end

      def estimated_duration
        # Return estimated migration duration in seconds
        nil
      end
    end
  end
end
```

**11.2.3 PostgreSQL to MySQL 8 Strategy**

```ruby
# lib/database_migration/strategies/postgresql_to_mysql8_strategy.rb
module DatabaseMigration
  module Strategies
    class PostgreSQLToMySQL8Strategy < Base
      attr_reader :migration_tool

      def initialize(config = {})
        super
        @migration_tool = config[:tool] || :pgloader
        @parallel_workers = config[:parallel_workers] || 8
      end

      def prepare(source, target)
        # Create backup of source database
        create_backup(source)

        # Verify target database is empty
        verify_target_empty(target)

        # Create pgloader configuration
        generate_pgloader_config if @migration_tool == :pgloader
      end

      def migrate(source, target)
        case @migration_tool
        when :pgloader
          PgloaderMigrator.new(@config).execute
        when :custom_etl
          CustomETLMigrator.new(@config).execute
        when :dump_and_load
          DumpAndLoadMigrator.new(@config).execute
        else
          raise "Unknown migration tool: #{@migration_tool}"
        end
      end

      def cleanup
        # Remove temporary files
        FileUtils.rm_f('migration.load')
      end

      def estimated_duration
        # Estimate based on source database size
        # Rough estimate: 1GB per 10 minutes
        source_size_gb = estimate_source_size / 1024.0 / 1024.0 / 1024.0
        (source_size_gb * 600).to_i
      end

      private

      def create_backup(source)
        BackupService.new(source).create_backup
      end

      def verify_target_empty(target)
        # Verify target database has no tables
        tables = target.connection.tables
        raise "Target database is not empty: #{tables}" if tables.any?
      end

      def generate_pgloader_config
        template = ERB.new(File.read('lib/database_migration/templates/pgloader.load.erb'))
        File.write('migration.load', template.result(binding))
      end

      def estimate_source_size
        # Return size in bytes
        ActiveRecord::Base.connection.select_value(
          "SELECT pg_database_size(current_database())"
        )
      end
    end
  end
end
```

**11.2.4 Strategy Factory**

```ruby
# lib/database_migration/strategy_factory.rb
module DatabaseMigration
  class StrategyFactory
    STRATEGY_MAP = {
      'postgresql_to_mysql2' => Strategies::PostgreSQLToMySQL8Strategy,
      'postgresql_to_mysql8' => Strategies::PostgreSQLToMySQL8Strategy,
      'mysql57_to_mysql8' => Strategies::MySQL57ToMySQL8Strategy,
      'mysql8_to_mysql9' => Strategies::MySQL8ToMySQL9Strategy
    }

    def self.create(source:, target:, config: {})
      strategy_key = "#{source.downcase}_to_#{target.downcase}"
      strategy_class = STRATEGY_MAP[strategy_key]

      unless strategy_class
        raise "No migration strategy found for #{source} → #{target}"
      end

      strategy_class.new(config)
    end

    def self.available_strategies
      STRATEGY_MAP.keys
    end
  end
end
```

### 11.3 Database Version Management

**11.3.1 Version Compatibility Configuration**

```yaml
# config/database_version_requirements.yml
mysql2:
  minimum_version: '8.0.0'
  recommended_version: '8.0.34'
  maximum_tested_version: '8.0.40'
  deprecated_below: '8.0.20'

  version_specific_features:
    '8.0.0':
      - 'caching_sha2_password'
      - 'utf8mb4_unicode_ci'
      - 'Window functions'
    '8.0.13':
      - 'CHECK constraints'
    '8.0.16':
      - 'Multi-valued indexes'
    '8.0.20':
      - 'Improved query optimizer'

postgresql:
  minimum_version: '12.0'
  recommended_version: '14.0'
  maximum_tested_version: '15.0'
```

**11.3.2 Version Manager**

```ruby
# lib/database_version_manager.rb
module DatabaseVersionManager
  class VersionCompatibility
    REQUIREMENTS_FILE = 'config/database_version_requirements.yml'

    def self.supported_versions(adapter:)
      requirements = load_requirements
      requirements[adapter.to_s] || {}
    end

    def self.verify_version!(adapter: nil)
      adapter ||= ActiveRecord::Base.connection.adapter_name.downcase.to_sym
      version = current_version(adapter)

      requirements = supported_versions(adapter: adapter)

      unless version_compatible?(version, requirements)
        raise DatabaseVersionError,
          "Unsupported database version: #{version}. " \
          "Minimum required: #{requirements['minimum_version']}, " \
          "Recommended: #{requirements['recommended_version']}"
      end

      if version_deprecated?(version, requirements)
        Rails.logger.warn(
          "Database version #{version} is deprecated. " \
          "Please upgrade to #{requirements['recommended_version']}"
        )
      end

      true
    end

    def self.current_version(adapter)
      case adapter.to_sym
      when :mysql2
        version_string = ActiveRecord::Base.connection.select_value('SELECT VERSION()')
        version_string.split('-').first
      when :postgresql
        ActiveRecord::Base.connection.select_value('SHOW server_version')
      else
        raise "Unknown adapter: #{adapter}"
      end
    end

    def self.upgrade_path(from:, to:)
      # Returns step-by-step upgrade instructions
      {
        from_version: from,
        to_version: to,
        steps: generate_upgrade_steps(from, to),
        estimated_downtime: estimate_upgrade_downtime(from, to)
      }
    end

    private

    def self.load_requirements
      YAML.load_file(Rails.root.join(REQUIREMENTS_FILE))
    end

    def self.version_compatible?(version, requirements)
      return true if requirements.empty?

      min_version = Gem::Version.new(requirements['minimum_version'])
      current = Gem::Version.new(version)

      current >= min_version
    end

    def self.version_deprecated?(version, requirements)
      return false unless requirements['deprecated_below']

      deprecated_version = Gem::Version.new(requirements['deprecated_below'])
      current = Gem::Version.new(version)

      current < deprecated_version
    end

    def self.generate_upgrade_steps(from, to)
      # Generate step-by-step upgrade instructions
      # This would be implemented based on specific version paths
      []
    end

    def self.estimate_upgrade_downtime(from, to)
      # Estimate downtime in minutes
      # This would be based on historical data
      30
    end
  end
end
```

**11.3.3 Version Check Initializer**

```ruby
# config/initializers/database_version_check.rb
Rails.application.config.after_initialize do
  if Rails.env.production? || Rails.env.staging?
    begin
      DatabaseVersionManager::VersionCompatibility.verify_version!
    rescue DatabaseVersionError => e
      Rails.logger.error "Database version check failed: #{e.message}"
      # In production, this should alert operations team
      # For now, we'll raise the error
      raise
    end
  end
end
```

### 11.4 Reusable Migration Components

**11.4.1 Generic Data Verifier**

```ruby
# lib/migration_utils/data_verifier.rb
module MigrationUtils
  class DataVerifier
    attr_reader :source_connection, :target_connection

    def initialize(source_connection, target_connection)
      @source_connection = source_connection
      @target_connection = target_connection
    end

    def verify_row_counts(tables)
      results = []

      tables.each do |table|
        source_count = @source_connection.select_value("SELECT COUNT(*) FROM #{table}")
        target_count = @target_connection.select_value("SELECT COUNT(*) FROM #{table}")

        results << {
          table: table,
          source_count: source_count,
          target_count: target_count,
          match: source_count == target_count,
          difference: source_count - target_count
        }
      end

      {
        table_results: results,
        all_matched: results.all? { |r| r[:match] },
        mismatches: results.reject { |r| r[:match] }
      }
    end

    def verify_schema_compatibility(table)
      source_columns = get_columns(@source_connection, table)
      target_columns = get_columns(@target_connection, table)

      {
        table: table,
        columns_match: source_columns.sort == target_columns.sort,
        missing_in_target: source_columns - target_columns,
        extra_in_target: target_columns - source_columns
      }
    end

    def verify_checksums(table, sample_size: 1000)
      # Sample-based checksum verification
      source_sample = get_sample_checksum(@source_connection, table, sample_size)
      target_sample = get_sample_checksum(@target_connection, table, sample_size)

      {
        table: table,
        checksum_match: source_sample == target_sample,
        source_checksum: source_sample,
        target_checksum: target_sample
      }
    end

    private

    def get_columns(connection, table)
      connection.columns(table).map(&:name)
    end

    def get_sample_checksum(connection, table, sample_size)
      # Get sample of rows and compute checksum
      # This is a simplified version
      rows = connection.select_all("SELECT * FROM #{table} LIMIT #{sample_size}")
      Digest::SHA256.hexdigest(rows.to_json)
    end
  end
end
```

**11.4.2 Migration Configuration Manager**

```ruby
# lib/database_migration/migration_config.rb
module DatabaseMigration
  class MigrationConfig
    CONFIG_FILE = 'config/database_migration.yml'

    attr_reader :config

    def initialize(overrides = {})
      @config = load_config.merge(overrides)
    end

    def migration_tool
      config[:migration][:tool]
    end

    def parallel_workers
      config[:migration][:parallel_workers]
    end

    def verification_threshold
      config[:migration][:verification][:row_count_threshold]
    end

    def retry_attempts
      config[:migration][:verification][:retry_attempts]
    end

    def target_downtime_minutes
      config[:migration][:performance][:target_downtime_minutes]
    end

    def query_timeout_ms
      config[:migration][:performance][:query_timeout_ms]
    end

    def to_h
      @config
    end

    private

    def load_config
      if File.exist?(Rails.root.join(CONFIG_FILE))
        base_config = YAML.load_file(Rails.root.join(CONFIG_FILE))
        env_config = base_config[Rails.env] || base_config['default'] || {}
        symbolize_keys(env_config)
      else
        default_config
      end
    end

    def default_config
      {
        migration: {
          tool: 'pgloader',
          parallel_workers: 8,
          verification: {
            row_count_threshold: 0,
            retry_attempts: 3
          },
          performance: {
            target_downtime_minutes: 30,
            query_timeout_ms: 5000
          }
        }
      }
    end

    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym).transform_values do |value|
        value.is_a?(Hash) ? symbolize_keys(value) : value
      end
    end
  end
end
```

**11.4.3 Migration Configuration File**

```yaml
# config/database_migration.yml
default: &default
  migration:
    tool: <%= ENV.fetch('DB_MIGRATION_TOOL', 'pgloader') %>
    verification:
      row_count_threshold: <%= ENV.fetch('DB_MIGRATION_ROW_COUNT_THRESHOLD', 0) %>
      retry_attempts: <%= ENV.fetch('DB_MIGRATION_RETRY_ATTEMPTS', 3) %>
      enable_checksum: <%= ENV.fetch('DB_MIGRATION_ENABLE_CHECKSUM', 'false') == 'true' %>
    performance:
      target_downtime_minutes: <%= ENV.fetch('DB_MIGRATION_TARGET_DOWNTIME', 30) %>
      query_timeout_ms: <%= ENV.fetch('DB_MIGRATION_QUERY_TIMEOUT', 5000) %>

production:
  <<: *default
  migration:
    tool: pgloader
    parallel_workers: <%= ENV.fetch('DB_MIGRATION_WORKERS', 8) %>
    verification:
      row_count_threshold: 0
      retry_attempts: 5
      enable_checksum: true

development:
  <<: *default
  migration:
    tool: <%= ENV.fetch('DB_MIGRATION_TOOL', 'dump_and_load') %>
    parallel_workers: 4

test:
  <<: *default
  migration:
    tool: dump_and_load
    parallel_workers: 2
```

**11.4.4 Backup Service**

```ruby
# lib/database_migration/services/backup_service.rb
module DatabaseMigration
  module Services
    class BackupService
      attr_reader :adapter, :config

      def initialize(adapter, config = {})
        @adapter = adapter
        @config = config
      end

      def create_backup
        case @adapter.adapter_name
        when 'postgresql'
          create_postgresql_backup
        when 'mysql2'
          create_mysql_backup
        else
          raise "Backup not supported for adapter: #{@adapter.adapter_name}"
        end
      end

      def restore_backup(backup_file)
        case @adapter.adapter_name
        when 'postgresql'
          restore_postgresql_backup(backup_file)
        when 'mysql2'
          restore_mysql_backup(backup_file)
        else
          raise "Restore not supported for adapter: #{@adapter.adapter_name}"
        end
      end

      private

      def create_postgresql_backup
        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        backup_file = "backup_postgresql_#{timestamp}.sql"

        cmd = [
          'pg_dump',
          '-h', ENV['PG_HOST'],
          '-U', ENV['PG_USER'],
          '-d', ENV['PG_DATABASE'],
          '-f', backup_file
        ].join(' ')

        system(cmd) || raise("PostgreSQL backup failed")
        backup_file
      end

      def create_mysql_backup
        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        backup_file = "backup_mysql_#{timestamp}.sql"

        cmd = [
          'mysqldump',
          '-h', ENV['MYSQL_HOST'],
          '-u', ENV['MYSQL_USER'],
          "-p#{ENV['MYSQL_PASSWORD']}",
          ENV['MYSQL_DATABASE'],
          '>', backup_file
        ].join(' ')

        system(cmd) || raise("MySQL backup failed")
        backup_file
      end

      def restore_postgresql_backup(backup_file)
        cmd = [
          'psql',
          '-h', ENV['PG_HOST'],
          '-U', ENV['PG_USER'],
          '-d', ENV['PG_DATABASE'],
          '<', backup_file
        ].join(' ')

        system(cmd) || raise("PostgreSQL restore failed")
      end

      def restore_mysql_backup(backup_file)
        cmd = [
          'mysql',
          '-h', ENV['MYSQL_HOST'],
          '-u', ENV['MYSQL_USER'],
          "-p#{ENV['MYSQL_PASSWORD']}",
          ENV['MYSQL_DATABASE'],
          '<', backup_file
        ].join(' ')

        system(cmd) || raise("MySQL restore failed")
      end
    end
  end
end
```

**11.4.5 Connection Manager**

```ruby
# lib/database_migration/services/connection_manager.rb
module DatabaseMigration
  module Services
    class ConnectionManager
      def self.establish_connection(adapter:, config:)
        case adapter
        when 'mysql2'
          Mysql2::Client.new(mysql_connection_params(config))
        when 'postgresql'
          PG.connect(postgresql_connection_params(config))
        else
          raise "Unsupported adapter: #{adapter}"
        end
      end

      def self.test_connection(adapter:, config:)
        connection = establish_connection(adapter: adapter, config: config)
        result = connection.ping || connection.select_value('SELECT 1')
        connection.close
        result
      rescue => e
        raise ConnectionError, "Failed to connect to #{adapter}: #{e.message}"
      end

      private

      def self.mysql_connection_params(config)
        {
          host: config[:host] || ENV['DB_HOST'],
          port: config[:port] || ENV.fetch('DB_PORT', 3306).to_i,
          username: config[:username] || ENV['DB_USERNAME'],
          password: config[:password] || ENV['DB_PASSWORD'],
          database: config[:database] || ENV['DB_NAME'],
          encoding: 'utf8mb4',
          reconnect: true
        }
      end

      def self.postgresql_connection_params(config)
        {
          host: config[:host] || ENV['PG_HOST'],
          port: config[:port] || ENV.fetch('PG_PORT', 5432).to_i,
          user: config[:username] || ENV['PG_USER'],
          password: config[:password] || ENV['PG_PASSWORD'],
          dbname: config[:database] || ENV['PG_DATABASE']
        }
      end
    end
  end
end
```

### 11.5 Read Replica and Horizontal Scaling Design

**11.5.1 Multi-Database Configuration**

```yaml
# config/database.yml (enhanced for read replicas)
production:
  primary:
    <<: *default
    database: <%= ENV.fetch("DB_NAME", "reline_production") %>
    host: <%= ENV.fetch("DB_PRIMARY_HOST", "localhost") %>
    username: <%= ENV.fetch("DB_PRIMARY_USERNAME", "reline_app") %>
    password: <%= ENV.fetch("DB_PRIMARY_PASSWORD") %>

  replica:
    <<: *default
    database: <%= ENV.fetch("DB_NAME", "reline_production") %>
    host: <%= ENV.fetch("DB_REPLICA_HOST", "localhost") %>
    username: <%= ENV.fetch("DB_REPLICA_USERNAME", "reline_app") %>
    password: <%= ENV.fetch("DB_REPLICA_PASSWORD") %>
    replica: true
```

**11.5.2 Sharding Configuration (Future Consideration)**

```yaml
# config/database_sharding.yml (optional, for future use)
production:
  sharding:
    enabled: <%= ENV.fetch('DB_SHARDING_ENABLED', 'false') == 'true' %>
    strategy: 'range' # or 'hash'
    shard_key: 'line_group_id'

    shards:
      shard_1:
        host: <%= ENV['DB_SHARD_1_HOST'] %>
        database: reline_production_shard_1
        range: [0, 50000]

      shard_2:
        host: <%= ENV['DB_SHARD_2_HOST'] %>
        database: reline_production_shard_2
        range: [50001, 100000]
```

**Note**: Read replica and sharding support are designed for future extensibility but not part of the initial migration implementation.

---

## 12. Deployment Plan

### 12.1 Pre-Deployment Checklist

- [ ] MySQL 8 instance provisioned and configured
- [ ] Database users created with appropriate permissions
- [ ] SSL/TLS certificates generated and configured
- [ ] Staging migration completed successfully
- [ ] All tests passing on staging
- [ ] Performance benchmarks meet targets
- [ ] Rollback plan tested and ready (M-9 verification completed)
- [ ] Backup storage verified (30-day retention)
- [ ] Maintenance window scheduled
- [ ] Team notified of deployment plan
- [ ] Monitoring and alerting configured

### 12.2 Deployment Timeline

**Total Estimated Time: 2-3 hours**

| Time | Duration | Phase | Activity |
|------|----------|-------|----------|
| T-30min | 30min | Preparation | Final verification, team standup |
| T+0 | 5min | Start | Enable maintenance mode, stop application |
| T+5 | 10min | Backup | Create final PostgreSQL backup |
| T+15 | 45min | Migration | Run pgloader, verify data |
| T+60 | 15min | Configuration | Update config files, bundle install |
| T+75 | 10min | Deploy | Restart application with MySQL 8 |
| T+85 | 15min | Verification | Smoke tests, monitoring check |
| T+100 | 5min | Complete | Disable maintenance mode |
| T+105 | 60min | Monitoring | Watch for errors, performance issues |

### 12.3 Maintenance Mode

**Enable Maintenance Mode:**
```ruby
# config/initializers/maintenance_mode.rb
class MaintenanceMode
  def self.enabled?
    File.exist?(Rails.root.join('tmp', 'maintenance.txt'))
  end
end

# Create middleware
class MaintenanceMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if MaintenanceMode.enabled?
      [503, {'Content-Type' => 'text/html'}, [maintenance_page]]
    else
      @app.call(env)
    end
  end

  private

  def maintenance_page
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Maintenance</title>
      </head>
      <body>
        <h1>System Maintenance</h1>
        <p>We're currently performing system maintenance. Please check back soon.</p>
      </body>
      </html>
    HTML
  end
end
```

**Commands:**
```bash
# Enable maintenance mode
touch tmp/maintenance.txt

# Disable maintenance mode
rm tmp/maintenance.txt
```

### 12.4 Post-Deployment Monitoring

**Metrics to Monitor:**
1. Application response time (target: < 200ms for 95th percentile)
2. Database query time (target: < 50ms average)
3. Error rate (target: < 0.1%)
4. Connection pool usage (target: < 80%)
5. Memory usage (target: < 80% of available)

**Monitoring Commands:**
```bash
# Monitor MySQL connections
mysql -e "SHOW STATUS LIKE 'Threads_connected';"

# Monitor slow queries
mysql -e "SHOW FULL PROCESSLIST;"

# Check application logs
tail -f log/production.log | grep ERROR

# Monitor system resources
top -p $(pgrep -f 'rails')
```

---

## 13. Documentation Requirements

### 13.1 Technical Documentation

**Required Documents:**
1. Migration runbook (detailed step-by-step guide)
2. Rollback procedures
3. Database configuration reference
4. Troubleshooting guide
5. Performance tuning guide

### 13.2 Operational Documentation

**Required Documents:**
1. Backup and restore procedures
2. Monitoring and alerting setup
3. Incident response playbook
4. Regular maintenance tasks

### 13.3 Developer Documentation

**Required Updates:**
1. README.md (update database setup instructions)
2. Development environment setup guide
3. Testing guidelines (MySQL-specific)
4. Database query best practices

---

## 14. Risk Assessment

### 14.1 Risk Matrix

| Risk ID | Risk Description | Impact | Likelihood | Severity | Mitigation |
|---------|-----------------|--------|------------|----------|------------|
| R-1 | Data loss during migration | High | Low | Critical | Multiple backups, verification scripts |
| R-2 | Extended downtime (> 30min) | Medium | Medium | High | Staging rehearsal, rollback plan |
| R-3 | Performance degradation | Medium | Medium | High | Performance testing, index optimization |
| R-4 | Application bugs post-migration | Medium | Low | Medium | Comprehensive testing, monitoring |
| R-5 | Rollback failure | High | Low | Critical | Test rollback procedure on staging |
| R-6 | Schema incompatibility | Low | Low | Low | Review all migrations, test on staging |
| R-7 | Security misconfiguration | High | Low | High | Security checklist, peer review |

### 14.2 Mitigation Strategies

**For R-1 (Data Loss):**
- Create multiple backups before migration
- Verify backups can be restored
- Run data verification scripts post-migration
- Keep PostgreSQL instance running for 30 days

**For R-2 (Extended Downtime):**
- Rehearse migration on staging environment
- Optimize migration scripts for speed
- Have rollback plan ready
- Schedule migration during low-traffic period

**For R-3 (Performance Degradation):**
- Benchmark queries on staging
- Add missing indexes before migration
- Configure MySQL for optimal performance
- Monitor key metrics post-deployment

**For R-4 (Application Bugs):**
- Run comprehensive test suite on staging
- Perform manual smoke testing
- Monitor error rates closely post-deployment
- Have rollback plan ready

**For R-5 (Rollback Failure):**
- Test complete rollback procedure on staging
- Document rollback steps clearly
- Automate rollback where possible
- Have PostgreSQL backup readily available

---

## 15. Success Metrics

### 15.1 Technical Metrics

**M-1: Migration Accuracy**
- Target: 100% of data migrated
- Measurement: Row count comparison, data checksums

**M-2: Downtime**
- Target: < 30 minutes
- Measurement: Time between maintenance mode start and completion

**M-3: Query Performance**
- Target: 95th percentile < 200ms
- Measurement: Application monitoring (New Relic, DataDog, etc.)

**M-4: Error Rate**
- Target: < 0.1% increase post-migration
- Measurement: Error tracking (Sentry, Rollbar, etc.)

**M-5: Test Coverage**
- Target: All tests passing on MySQL 8
- Measurement: RSpec test results

**M-9: Rollback Plan Verification**
- Target: Rollback procedure tested successfully on staging environment
- Measurement: Rollback execution time < 10 minutes, 100% success rate

### 15.2 Operational Metrics

**M-6: Team Confidence**
- Target: All team members trained on MySQL operations
- Measurement: Training completion, documentation review

**M-7: Incident Response**
- Target: No critical incidents in first 7 days
- Measurement: Incident tracking system

**M-8: Backup Success**
- Target: 100% backup success rate
- Measurement: Automated backup monitoring

---

## 16. Timeline and Milestones

### 16.1 Project Timeline

**Week 1: Preparation**
- Day 1-2: Provision MySQL 8 instance
- Day 3-4: Update configuration files, Gemfile
- Day 5: Review all migrations for compatibility

**Week 2: Testing**
- Day 1-3: Set up staging environment
- Day 4-5: Run migration on staging

**Week 3: Validation**
- Day 1-2: Verify staging migration
- Day 3-4: Run full test suite on staging
- Day 5: Performance testing and optimization

**Week 4: Production Migration**
- Day 1-2: Final preparation, team training
- Day 3: **Production Migration** (maintenance window)
- Day 4-5: Post-migration monitoring and bug fixes

### 16.2 Milestones

- [ ] **M1**: MySQL 8 instance provisioned (Week 1)
- [ ] **M2**: Configuration updated and tested locally (Week 1)
- [ ] **M3**: Staging migration completed (Week 2)
- [ ] **M4**: All tests passing on staging (Week 3)
- [ ] **M5**: Production migration completed (Week 4)
- [ ] **M6**: 7-day stable operation (Week 5)
- [ ] **M7**: PostgreSQL decommissioned (Week 8)

---

## 17. Appendix

### 17.1 MySQL 8 Configuration Recommendations

**my.cnf (Production):**
```ini
[mysqld]
# Character set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Connection limits
# Note: max_connections=200 supports up to 20 application instances with pool size of 10
max_connections=200
max_connect_errors=100

# Buffer sizes
innodb_buffer_pool_size=1G  # Adjust based on available RAM
innodb_log_file_size=256M

# Performance
innodb_flush_log_at_trx_commit=2
innodb_flush_method=O_DIRECT

# Security
require_secure_transport=ON
default_authentication_plugin=caching_sha2_password

# Logging (disable after migration)
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow-query.log
long_query_time=1
```

### 17.2 Useful MySQL Commands

```sql
-- Check database size
SELECT
  table_schema AS 'Database',
  ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'reline_production'
GROUP BY table_schema;

-- Check table sizes
SELECT
  table_name AS 'Table',
  ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'reline_production'
ORDER BY (data_length + index_length) DESC;

-- Check active connections
SHOW FULL PROCESSLIST;

-- Check slow queries
SELECT * FROM mysql.slow_log ORDER BY query_time DESC LIMIT 10;

-- Optimize tables after migration
OPTIMIZE TABLE alarm_contents, contents, feedbacks, line_groups, operators;
```

### 17.3 Resources

**Documentation:**
- MySQL 8.0 Reference Manual: https://dev.mysql.com/doc/refman/8.0/en/
- Rails Database Configuration: https://guides.rubyonrails.org/configuring.html#configuring-a-database
- pgloader Documentation: https://pgloader.readthedocs.io/

**Tools:**
- pgloader: PostgreSQL to MySQL migration tool
- MySQL Workbench: GUI for MySQL management
- pt-table-checksum: Percona tool for data verification

---

## 18. Conclusion

This design provides a comprehensive plan for unifying the database system to MySQL 8 across all environments. The multi-phase migration approach minimizes risk while ensuring data integrity and maintaining application stability.

**Key Takeaways:**
1. Environment parity will eliminate SQL compatibility issues
2. Careful planning and testing reduce migration risks
3. Comprehensive monitoring ensures early detection of issues
4. Rollback capability provides safety net
5. Documentation ensures long-term maintainability
6. Abstraction layers enable future database migrations
7. Observability tools provide production visibility

**Next Steps:**
1. Review and approve this design document
2. Provision MySQL 8 infrastructure
3. Execute migration plan on staging environment
4. Schedule production migration window
5. Perform production migration
6. Monitor and optimize post-migration

---

**Document Status**: ✅ Ready for Review (Iteration 2)
**Reviewer**: Main Claude Code / EDAF Evaluators
**Approval Required**: Design evaluators (7/7)
**Changes Made in Iteration 2**:
1. ✅ Fixed Rails/Ruby version inconsistency (6.1.4 / 3.0.2)
2. ✅ Added comprehensive Observability section (Section 10)
3. ✅ Added Extensibility improvements (Section 11)
4. ✅ Added Reusability components (Section 11.4)
5. ✅ Added M-9: Rollback verification metric
6. ✅ Added SC-7: SQL injection security control
7. ✅ Clarified downtime target definition
8. ✅ Standardized SSL certificate paths to /etc/mysql/certs/
9. ✅ Added connection pool explanation in Section 17.1
