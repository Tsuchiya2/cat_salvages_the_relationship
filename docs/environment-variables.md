# Environment Variables Documentation

**Feature**: FEAT-DB-001 - MySQL 8 Database Unification
**Version**: 1.0
**Last Updated**: 2025-11-24

---

## Overview

This document describes all environment variables required for MySQL 8.0+ database configuration across all environments (development, test, production).

---

## Required Variables

### DB_HOST

**Description**: Database server hostname or IP address

**Required**: Yes

**Default**: `localhost`

**Examples**:
- Development: `localhost`
- Production: `mysql.example.com` or `10.0.1.50`

**Usage**:
```bash
DB_HOST=localhost
```

---

### DB_PORT

**Description**: Database server port number

**Required**: Yes

**Default**: `3306`

**Examples**:
- Standard MySQL: `3306`
- Custom port: `3307`

**Usage**:
```bash
DB_PORT=3306
```

---

### DB_NAME

**Description**: Database name for the current environment

**Required**: Yes

**Default**:
- Development: `reline_development`
- Test: `reline_test`
- Production: No default (must be set)

**Examples**:
- Development: `reline_development`
- Test: `reline_test`
- Production: `reline_production`

**Usage**:
```bash
# Development
DB_NAME=reline_development

# Production
DB_NAME=reline_production
```

---

### DB_USERNAME

**Description**: Database user for authentication

**Required**: Yes

**Default**: None (must be set)

**Security Notes**:
- **NEVER commit credentials to Git**
- Use separate users for each environment
- Grant minimum required privileges

**Examples**:
- Development: `root` or `dev_user`
- Production: `reline_app_user`

**Usage**:
```bash
# Development
DB_USERNAME=root

# Production
DB_USERNAME=reline_app_user
```

---

### DB_PASSWORD

**Description**: Database password for authentication

**Required**: Yes

**Default**: None (must be set)

**Security Notes**:
- **NEVER commit passwords to Git**
- Use strong passwords in production
- Rotate passwords regularly
- Store in secure secret management system

**Examples**:
```bash
# Development (can be empty for local MySQL)
DB_PASSWORD=

# Production (MUST be strong password)
DB_PASSWORD=SecureP@ssw0rd123!
```

---

## SSL Configuration (Production Only)

### DB_SSL_CA

**Description**: Path to SSL Certificate Authority file for encrypted connections

**Required**: No (recommended for production)

**Default**: `nil` (SSL disabled)

**Examples**:
```bash
DB_SSL_CA=/path/to/ca-cert.pem
```

**Notes**:
- Required for encrypted MySQL connections
- Verify certificate path is accessible to the application
- Commonly used with cloud-hosted databases (AWS RDS, Google Cloud SQL)

---

### DB_SSL_KEY

**Description**: Path to SSL private key file for client authentication

**Required**: No (optional with SSL)

**Default**: `nil`

**Examples**:
```bash
DB_SSL_KEY=/path/to/client-key.pem
```

**Notes**:
- Used for mutual TLS (mTLS) authentication
- Must match `DB_SSL_CERT`

---

### DB_SSL_CERT

**Description**: Path to SSL certificate file for client authentication

**Required**: No (optional with SSL)

**Default**: `nil`

**Examples**:
```bash
DB_SSL_CERT=/path/to/client-cert.pem
```

**Notes**:
- Used for mutual TLS (mTLS) authentication
- Must match `DB_SSL_KEY`

---

## Additional Variables

### RAILS_ENV

**Description**: Rails environment name

**Required**: Yes

**Default**: `development`

**Valid Values**:
- `development`
- `test`
- `production`

**Usage**:
```bash
RAILS_ENV=production
```

---

### RAILS_MAX_THREADS

**Description**: Maximum number of threads for Puma server and database connections

**Required**: No

**Default**: `5`

**Examples**:
```bash
# Development
RAILS_MAX_THREADS=5

# Production (increase for higher concurrency)
RAILS_MAX_THREADS=10
```

**Notes**:
- Used to determine database connection pool size
- Should match Puma thread count
- Higher values = more concurrent database connections

---

## Environment-Specific Configuration

### Development Environment

**Minimum Required Variables**:
```bash
DB_HOST=localhost
DB_PORT=3306
DB_NAME=reline_development
DB_USERNAME=root
DB_PASSWORD=
RAILS_ENV=development
```

**Setup**:
```bash
# Copy example file
cp .env.example .env

# Edit .env with your local MySQL credentials
# Start development server
rails server
```

---

### Test Environment

**Minimum Required Variables**:
```bash
DB_HOST=localhost
DB_PORT=3306
DB_NAME=reline_test
DB_USERNAME=root
DB_PASSWORD=
RAILS_ENV=test
```

**Setup**:
```bash
# Create test database
RAILS_ENV=test rails db:create db:migrate

# Run tests
rspec
```

---

### Production Environment

**Minimum Required Variables**:
```bash
DB_HOST=production-mysql.example.com
DB_PORT=3306
DB_NAME=reline_production
DB_USERNAME=reline_app_user
DB_PASSWORD=<SECURE_PASSWORD>
RAILS_ENV=production
RAILS_MAX_THREADS=10
```

**With SSL (Recommended)**:
```bash
DB_HOST=production-mysql.example.com
DB_PORT=3306
DB_NAME=reline_production
DB_USERNAME=reline_app_user
DB_PASSWORD=<SECURE_PASSWORD>
DB_SSL_CA=/etc/ssl/certs/mysql-ca.pem
DB_SSL_KEY=/etc/ssl/private/mysql-client-key.pem
DB_SSL_CERT=/etc/ssl/certs/mysql-client-cert.pem
RAILS_ENV=production
RAILS_MAX_THREADS=10
```

---

## Security Best Practices

### 1. Never Commit Secrets

**Add to `.gitignore`**:
```
.env
.env.local
.env.production
```

**Verify**:
```bash
# Check if .env is ignored
git status

# .env should NOT appear in untracked files
```

---

### 2. Use Environment-Specific Files

**File Structure**:
```
.env.example          # Template (committed to Git)
.env                  # Development (NOT committed)
.env.test             # Test (NOT committed)
.env.production       # Production (NOT committed)
```

**Usage**:
```bash
# Load environment-specific file
rails server  # Automatically loads .env in development
```

---

### 3. Secret Management in Production

**Recommended Approaches**:

1. **Environment Variables** (Heroku, Cloud Platforms):
   ```bash
   heroku config:set DB_PASSWORD=SecurePassword
   ```

2. **Secret Management Services**:
   - AWS Secrets Manager
   - Google Cloud Secret Manager
   - HashiCorp Vault

3. **Rails Encrypted Credentials**:
   ```bash
   rails credentials:edit
   ```

---

## Validation

### Check Configuration

**Verify database.yml**:
```bash
# Check syntax
ruby -c config/database.yml

# View resolved configuration
rails runner "puts ActiveRecord::Base.connection_db_config.configuration_hash"
```

**Test Database Connection**:
```bash
# Development
rails db:migrate:status

# Test
RAILS_ENV=test rails db:migrate:status

# Production (on production server)
RAILS_ENV=production rails db:migrate:status
```

---

## Troubleshooting

### Issue: "Access denied for user"

**Cause**: Incorrect `DB_USERNAME` or `DB_PASSWORD`

**Solution**:
```bash
# Verify credentials
mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p

# Check .env file
cat .env | grep DB_
```

---

### Issue: "Unknown database"

**Cause**: Database `DB_NAME` does not exist

**Solution**:
```bash
# Create database
rails db:create

# Or manually
mysql -u root -p -e "CREATE DATABASE reline_development CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

---

### Issue: "Can't connect to MySQL server"

**Cause**: Incorrect `DB_HOST` or `DB_PORT`, or MySQL not running

**Solution**:
```bash
# Check if MySQL is running
mysql -h localhost -u root -p

# Check port
netstat -an | grep 3306

# Verify environment variables
echo $DB_HOST
echo $DB_PORT
```

---

### Issue: SSL connection error

**Cause**: Incorrect SSL certificate paths or permissions

**Solution**:
```bash
# Verify certificate files exist
ls -l $DB_SSL_CA $DB_SSL_KEY $DB_SSL_CERT

# Check file permissions
chmod 600 /path/to/client-key.pem

# Test SSL connection manually
mysql -h $DB_HOST -u $DB_USERNAME -p --ssl-ca=$DB_SSL_CA
```

---

## Migration from PostgreSQL

When migrating from PostgreSQL to MySQL 8, update environment variables:

**Before (PostgreSQL)**:
```bash
DATABASE_URL=postgresql://user:pass@localhost/dbname
```

**After (MySQL 8)**:
```bash
DB_HOST=localhost
DB_PORT=3306
DB_NAME=reline_production
DB_USERNAME=user
DB_PASSWORD=pass
```

**Note**: Remove `DATABASE_URL` as it may override `database.yml` settings.

---

## References

- [Rails Configuration Guide](https://guides.rubyonrails.org/configuring.html#configuring-a-database)
- [MySQL 8 SSL Configuration](https://dev.mysql.com/doc/refman/8.0/en/using-encrypted-connections.html)
- [12-Factor App - Config](https://12factor.net/config)

---

**Next Steps**:
1. Copy `.env.example` to `.env`
2. Set environment-specific values
3. Test database connection
4. Run migrations
