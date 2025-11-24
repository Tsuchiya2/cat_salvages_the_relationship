# Design Document Update Summary

## Status
**Current Iteration**: 1
**Target Iteration**: 2
**Update Date**: 2025-11-24
**Reason**: Address evaluator feedback (Extensibility, Observability, Reusability)

---

## Critical Issues to Address

Based on evaluation feedback from:
- `docs/evaluations/design-extensibility-FEAT-AUTH-001.md` (Score: 6.5/10.0) - **Request Changes**
- `docs/evaluations/rails8-authentication-migration-observability-evaluation.md` (Score: 3.2/5.0) - **Request Changes**
- `docs/evaluations/rails8-authentication-migration-reusability-evaluation.md` (Score: 3.6/5.0) - **Request Changes**

---

## Required Changes

### 1. EXTENSIBILITY IMPROVEMENTS

#### 1.1 Add Authentication::Provider Abstraction (HIGH PRIORITY)

**Current Problem**: Password authentication is hardcoded in Authentication concern - cannot add OAuth, SAML, MFA without extensive refactoring.

**Solution**: Create provider interface pattern

**New Files to Add**:
- `app/services/authentication/provider.rb` - Abstract base class
- `app/services/authentication/password_provider.rb` - Password implementation
- `app/services/authentication_service.rb` - Framework-agnostic service layer
- `app/services/auth_result.rb` - Result object for authentication attempts

**Design Section to Update**: Section 3.3.1 (new subsection after Component Architecture)

**Benefits**:
- Add OAuth (Google, GitHub) without modifying existing code
- Add MFA layer on top of any provider
- Support CLI, API, background job contexts

---

#### 1.2 Add MFA Database Schema and Flow (HIGH PRIORITY - SECURITY)

**Current Problem**: No MFA planning - adding later requires extensive refactoring and is critical for security/compliance.

**Solution**: Add MFA fields to database schema now, design MFA flow

**New Migration**:
```ruby
add_column :operators, :mfa_enabled, :boolean, default: false
add_column :operators, :mfa_secret, :string
add_column :operators, :mfa_method, :string # 'totp', 'sms', 'email'
add_column :operators, :mfa_backup_codes, :text
```

**Design Sections to Update**:
- Section 2.2.5 (new) - Future Extension Requirements
- Section 4.1.4 (new) - MFA Migration
- Section 4.2 (update) - Final Schema

---

#### 1.3 Add OAuth Integration Design (MEDIUM PRIORITY)

**Current Problem**: No OAuth planning - cannot add Google/GitHub login without refactoring.

**Solution**: Add OAuth fields and provider design

**New Migration**:
```ruby
add_column :operators, :oauth_provider, :string
add_column :oauth_uid, :string
change_column_null :operators, :password_digest, true # Allow OAuth-only users
```

**Design Sections to Update**:
- Section 4.1.5 (new) - OAuth Migration
- Section 4.2 (update) - Final Schema

---

#### 1.4 Move Security Parameters to ENV Variables (MEDIUM PRIORITY)

**Current Problem**: Configuration hardcoded in constants - cannot change security parameters without code deployment.

**Solution**: Create configuration initializer with ENV variables

**Configuration File**: `config/initializers/authentication_config.rb`

**ENV Variables**:
- `LOGIN_RETRY_LIMIT` (default: 5)
- `LOGIN_LOCK_DURATION` (default: 45 minutes)
- `PASSWORD_MIN_LENGTH` (default: 8)
- `SESSION_TIMEOUT` (default: 30 minutes)
- `BCRYPT_COST` (default: 12 for production)
- `AUTH_OAUTH_ENABLED` (feature flag)
- `AUTH_MFA_ENABLED` (feature flag)

**Design Section to Add**: Section 6.5 (new) - Configuration Management

---

### 2. OBSERVABILITY IMPROVEMENTS

#### 2.1 Add Structured Logging (HIGH PRIORITY)

**Current Problem**: Logs are string concatenation - difficult to parse and search programmatically.

**Solution**: Implement Lograge for structured JSON logging

**Gem to Add**: `lograge`

**Configuration**: `config/initializers/lograge.rb`

**Log Fields Required**:
- `request_id` (correlation)
- `event` (e.g., 'authentication_attempt')
- `email`
- `ip`
- `user_agent`
- `timestamp` (ISO 8601)
- `result` (:success | :failed)
- `reason` (e.g., :invalid_credentials)

**Design Section to Add**: Section 9.6.1 (new) - Structured Logging Configuration

---

#### 2.2 Add Metrics Instrumentation (HIGH PRIORITY)

**Current Problem**: Relies on database queries for metrics - inefficient, not real-time, adds DB load.

**Solution**: Implement StatsD for event-driven metrics collection

**Gem to Add**: `statsd-instrument`

**Metrics to Emit**:
- `auth.attempts` (counter, tags: provider, result)
- `auth.duration` (timing)
- `auth.failures` (counter, tags: reason)
- `auth.account_locked` (counter)

**Design Section to Add**: Section 9.6.2 (new) - Metrics Instrumentation

---

#### 2.3 Add Request Correlation (HIGH PRIORITY)

**Current Problem**: Missing request IDs in logs - cannot trace user authentication journey across multiple requests.

**Solution**: Use Rails `request.request_id` consistently, propagate to background jobs

**Implementation**:
- Add request_id to all authentication logs
- Propagate to SessionMailer via headers
- Use RequestStore for cross-thread access

**Design Section to Add**: Section 9.6.3 (new) - Distributed Tracing (Request Correlation)

---

#### 2.4 Specify Log Aggregation Strategy (MEDIUM PRIORITY)

**Current Problem**: No log centralization - difficult to search logs across instances.

**Solution**: Choose log aggregation tool (CloudWatch, Papertrail, Splunk)

**Recommendation**: CloudWatch Logs (AWS) or Papertrail

**Log Retention Policy**:
- Development: 7 days
- Staging: 30 days
- Production: 90 days
- Archive to S3 for 7 years (compliance)

**Design Section to Add**: Section 9.6.5 (new) - Log Aggregation Strategy

---

#### 2.5 Add Prometheus Metrics Endpoint (LOW PRIORITY - FUTURE)

**Solution**: Add `/metrics` endpoint for Prometheus scraping

**Gem to Add**: `prometheus_exporter`

**Design Section to Add**: Section 9.6.4 (new) - Prometheus Metrics Endpoint

---

### 3. REUSABILITY IMPROVEMENTS

#### 3.1 Parameterize Concerns for Multiple Model Types (HIGH PRIORITY)

**Current Problem**: Authentication concern is tightly coupled to Operator model - cannot reuse for Admin, Customer models.

**Solution**: Create generic `Authenticatable` concern with model configuration

**New Concern**: `app/controllers/concerns/authenticatable.rb`

**Usage Pattern**:
```ruby
class Operator::BaseController < ApplicationController
  include Authenticatable
  authenticates_with model: Operator, path_prefix: 'operator'
end

# Future: Admin authentication
class Admin::BaseController < ApplicationController
  include Authenticatable
  authenticates_with model: Admin, path_prefix: 'admin'
end
```

**Design Section to Add**: Section 13.3 (new in Section 13) - Multi-Model Authentication Pattern

---

#### 3.2 Extract Japanese Messages to I18n (MEDIUM PRIORITY)

**Current Problem**: Japanese UI messages hardcoded in controllers - not maintainable, cannot support multi-locale.

**Solution**: Extract all user-facing messages to locale files

**Files to Create**:
- `config/locales/ja.yml` (Japanese)
- `config/locales/en.yml` (English)

**Before**:
```ruby
flash[:success] = "🐾 キャットイン 🐾"
```

**After**:
```ruby
flash[:success] = t('operator.sessions.login_success')
```

**Design Section to Add**: Section 13.2 (new in Section 13) - I18n Extraction

---

#### 3.3 Create AuthenticationService Layer (HIGH PRIORITY)

**Current Problem**: Business logic mixed with HTTP concerns - cannot reuse in CLI, API, background jobs.

**Solution**: Extract AuthenticationService (framework-agnostic)

**New File**: `app/services/authentication_service.rb`

**Benefits**:
- Reusable in HTTP controllers, API controllers, CLI tools, background jobs
- Testable in isolation
- Separation of concerns (business logic vs presentation)

**Design Section**: Already covered in Section 1.1 (Authentication::Provider Abstraction)

---

#### 3.4 Create Utility Classes (MEDIUM PRIORITY)

**Current Problem**: Code duplication - email validation regex, session management logic repeated.

**Solution**: Extract shared utilities

**New Files**:
- `lib/validators/email_validator.rb` - Email format validation
- `app/services/session_manager.rb` - Session lifecycle management
- `app/services/password_migrator.rb` - Generic password migration utility
- `lib/data_migration_validator.rb` - Migration safety checks

**Design Section to Add**: Section 13.1.3 (new in Section 13) - Shared Utilities

---

### 4. OBSERVABILITY TESTING

**Current Problem**: No tests for logging and metrics emission.

**Solution**: Add observability testing section

**Test Examples**:
- Test that logs are emitted with correct structure
- Test that metrics are incremented on authentication events
- Test that request_id is propagated

**Design Section to Add**: Section 8.7 (new) - Observability Testing

---

## Document Structure Changes

### New Sections to Add:

1. **Section 2.2.5** - Future Extension Requirements (after FR-7)
2. **Section 3.3.1** - Authentication Provider Abstraction (after Component Architecture)
3. **Section 4.1.4** - MFA Migration (after Migration 3)
4. **Section 4.1.5** - OAuth Migration (after MFA Migration)
5. **Section 6.5** - Configuration Management (after Security Testing Plan)
6. **Section 8.7** - Observability Testing (after Security Testing)
7. **Section 9.6** - Observability Setup (after Monitoring and Validation)
   - 9.6.1 Structured Logging Configuration
   - 9.6.2 Metrics Instrumentation
   - 9.6.3 Distributed Tracing (Request Correlation)
   - 9.6.4 Prometheus Metrics Endpoint (Future)
   - 9.6.5 Log Aggregation Strategy
   - 9.6.6 Monitoring Dashboards
8. **Section 11.5** - Observability Metrics (after Success Metrics)
9. **Section 13** - Reusability Guidelines (new major section)
   - 13.1 Reusable Components
   - 13.2 I18n Extraction
   - 13.3 Multi-Model Authentication Pattern
   - 13.4 Porting Guide

### Sections to Update:

1. **Metadata** (lines 12-22) - Change iteration from 1 to 2
2. **Section 4.2** (lines 485-517) - Update Final Schema to include MFA and OAuth fields

---

## Estimated Effort

**Total Additions**: ~1,500 lines of new content
**Total Updates**: ~50 lines of existing content modifications

**Time Estimate**: 3-4 hours to apply all changes

---

## Implementation Approach

Given the file size (2,805 lines), I recommend:

**Option 1: Manual Insertion** (Most reliable)
1. Read the patch file: `docs/designs/rails8-authentication-migration.md.patch`
2. Insert sections at specified line numbers
3. Update modified sections

**Option 2: Automated Script** (Faster but requires verification)
1. Create a script to parse and insert sections
2. Verify output manually
3. Run tests to ensure correctness

**Option 3: Hybrid Approach** (Recommended)
1. I'll create a new complete file with all changes integrated
2. You can review the diff
3. Replace the original file

---

## Next Steps

**Would you like me to:**
1. Create the complete updated design document now? (Recommended)
2. Create a detailed insertion script with line numbers?
3. Create individual section files that you can merge manually?

**My recommendation**: Option 1 - I'll create the complete updated design document with all improvements integrated. This ensures consistency and correctness.

Shall I proceed with creating the fully updated design document?
