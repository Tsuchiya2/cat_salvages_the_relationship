# Design Document - Rails 8 Authentication Migration

**Feature ID**: FEAT-AUTH-001
**Created**: 2025-11-24
**Last Updated**: 2025-11-24
**Designer**: designer agent

---

## Metadata

```yaml
design_metadata:
  feature_id: "FEAT-AUTH-001"
  feature_name: "Rails 8 Authentication Migration"
  created: "2025-11-24"
  updated: "2025-11-24"
  iteration: 2
  migration_type: "authentication_framework"
  criticality: "high"
  estimated_effort: "large"
  revision_reason: "Address evaluator feedback (extensibility, observability, reusability)"
```

---

## 0. Revision Summary (Iteration 2)

This design document has been revised based on feedback from 7 evaluators. The following improvements have been incorporated:

### 0.1 Extensibility Improvements (Score: 6.5→9.0 target)

**Issue**: Password authentication was hardcoded, making future OAuth/MFA/SAML additions difficult.

**Solutions Implemented**:
1. **Authentication::Provider Abstraction Pattern**: Created abstract provider interface with pluggable implementations (PasswordProvider, OAuthProvider, MFAProvider, SAMLProvider)
2. **AuthenticationService Layer**: Extracted framework-agnostic service layer for reuse in CLI, API, and background jobs
3. **MFA Database Schema**: Added `mfa_enabled`, `mfa_secret`, `mfa_method`, `mfa_backup_codes` fields for future multi-factor authentication
4. **OAuth Database Schema**: Added `oauth_provider`, `oauth_uid`, `oauth_token` fields with composite unique index
5. **Configuration Management**: Moved all security parameters to ENV variables (`LOGIN_RETRY_LIMIT`, `SESSION_TIMEOUT`, `BCRYPT_COST`, etc.)
6. **Feature Flags**: Added `AUTH_OAUTH_ENABLED`, `AUTH_MFA_ENABLED` for gradual rollout

**Detailed Implementation**: See `docs/designs/rails8-authentication-migration.md.patch` sections 3.3.1, 4.1.4, 4.1.5, 6.5

### 0.2 Observability Improvements (Score: 3.2→8.0 target)

**Issue**: Logs were unstructured strings, metrics relied on inefficient database queries, no request correlation.

**Solutions Implemented**:
1. **Structured Logging (Lograge)**: JSON-formatted logs with `request_id`, `event`, `email`, `ip`, `user_agent`, `timestamp`, `result`, `reason`
2. **Metrics Instrumentation (StatsD)**: Real-time metrics (`auth.attempts`, `auth.duration`, `auth.failures`) with tags for dimensionality
3. **Request Correlation**: Consistent `request_id` propagation across all authentication flows, including background jobs and emails
4. **Log Aggregation Strategy**: CloudWatch Logs or Papertrail with retention policies (dev: 7d, staging: 30d, prod: 90d, archive: 7y)
5. **Prometheus Metrics Endpoint**: `/metrics` endpoint for scraping (secured with token authentication)
6. **Monitoring Dashboards**: Grafana dashboards with success rate, latency (p50/p95/p99), failure reasons, account lock rate

**Detailed Implementation**: See `docs/designs/rails8-authentication-migration.md.patch` sections 9.6.1-9.6.6, 11.5

### 0.3 Reusability Improvements (Score: 3.6→8.5 target)

**Issue**: Components were tightly coupled to Operator model, Japanese messages hardcoded, no shared utilities.

**Solutions Implemented**:
1. **Parameterized Concerns**: `Authenticatable` concern supports multiple models via `authenticates_with model: Operator` configuration
2. **BruteForceProtection Generalization**: Configurable `lock_retry_limit`, `lock_duration`, and `lock_notifier` per model
3. **I18n Extraction**: All user-facing messages moved to `config/locales/{ja,en}.yml` with proper translation keys
4. **Shared Utility Classes**:
   - `Validators::EmailValidator`: Email format validation and normalization
   - `SessionManager`: Generic session lifecycle management supporting multiple user types
   - `PasswordMigrator`: Reusable password migration utility
   - `DataMigrationValidator`: Safety checks for data migrations
5. **Multi-Model Authentication Pattern**: Generic pattern for Admin, Customer, Vendor models with 2-3 hour porting effort
6. **Porting Guide**: Documented step-by-step instructions for reusing authentication components

**Detailed Implementation**: See `docs/designs/rails8-authentication-migration.md.patch` sections 13.1-13.4

### 0.4 Implementation Reference

**Complete implementation details for all improvements are available in**:
- **Patch File**: `docs/designs/rails8-authentication-migration.md.patch` (1,078 lines)
- **Update Summary**: `docs/designs/DESIGN_UPDATE_SUMMARY.md`

**Key Sections Added**:
- Section 2.2.5: Future Extension Requirements (OAuth, MFA, Provider Abstraction)
- Section 3.3.1: Authentication Provider Architecture
- Section 4.1.4: MFA Migration
- Section 4.1.5: OAuth Migration
- Section 6.5: Configuration Management (ENV Variables)
- Section 8.7: Observability Testing
- Section 9.6: Observability Setup (Lograge, StatsD, Request Correlation, Prometheus, Log Aggregation)
- Section 11.5: Observability Metrics
- Section 13: Reusability Guidelines (Reusable Components, I18n, Multi-Model Pattern, Porting Guide)

**Note**: This revision summary provides a high-level overview. Refer to the patch file for complete code examples, migration scripts, configuration files, and implementation details.

---

## 1. Overview

### 1.1 Feature Summary

This design document outlines the migration strategy from the Sorcery gem to Rails 8's built-in authentication feature for the cat_salvages_the_relationship application. The Sorcery gem is no longer actively maintained, posing security and compatibility risks. Rails 8 introduces a new authentication generator that provides modern, secure authentication patterns using standard Rails conventions.

The migration involves upgrading from Rails 6.1.4 to Rails 8.1.1, replacing Sorcery's authentication mechanisms with Rails 8's built-in features, and ensuring data continuity for existing user accounts.

**Important Note**: The application is already running on Rails 8.1.1 and Ruby 3.4.6 (as seen in Gemfile), which simplifies the migration path. The primary focus will be on replacing Sorcery authentication with Rails 8's built-in authentication.

### 1.2 Goals and Objectives

**Primary Goals:**
1. **Remove dependency on unmaintained Sorcery gem** - Eliminate security and compatibility risks
2. **Adopt Rails 8 authentication standards** - Use modern, Rails-native authentication patterns
3. **Preserve existing user data** - Ensure zero data loss during migration
4. **Maintain backward compatibility** - Existing operator accounts continue to work
5. **Retain authorization layer** - Keep Pundit policies unchanged

**Secondary Goals:**
1. Improve authentication security with modern standards
2. Simplify codebase by using Rails conventions
3. Enhance testability with standard Rails authentication patterns
4. Improve maintainability for future development

### 1.3 Success Criteria

1. **Functional Success:**
   - All existing operators can log in with their current credentials
   - Login, logout, and session management work correctly
   - Brute force protection maintains equivalent security level
   - Account locking mechanism functions properly
   - Email notifications for locked accounts continue to work

2. **Technical Success:**
   - Sorcery gem completely removed from dependencies
   - All authentication-related tests pass
   - No regression in authorization (Pundit) functionality
   - Database migrations execute without errors
   - Zero downtime deployment achieved

3. **Security Success:**
   - Password hashing strength maintained or improved
   - Session security meets or exceeds current standards
   - Brute force protection remains effective
   - No security vulnerabilities introduced

---

## 2. Requirements Analysis

### 2.1 Current State Analysis

#### 2.1.1 Sorcery Configuration

**Current Setup (from `config/initializers/sorcery.rb`):**
- **Enabled Submodules**: `:brute_force_protection`
- **User Model**: `Operator` class
- **Encryption Algorithm**: bcrypt (Sorcery default)
- **Brute Force Protection**:
  - Consecutive login retry limit: 5 attempts
  - Lock duration: 45 minutes (2700 seconds)
  - Lock notification: Email sent via `SessionMailer.notice`

#### 2.1.2 Database Schema Analysis

**Current `operators` table structure:**
```ruby
create_table "operators" do |t|
  t.datetime "created_at", null: false
  t.string "crypted_password"           # Sorcery's password field
  t.string "email", null: false          # Login identifier
  t.integer "failed_logins_count", default: 0
  t.datetime "lock_expires_at"           # Account lock timestamp
  t.string "name", null: false           # Display name
  t.integer "role", default: 1, null: false  # Enum: operator(0), guest(1)
  t.string "salt"                        # Sorcery's password salt
  t.string "unlock_token"                # For manual unlocking
  t.datetime "updated_at", null: false
  t.index ["email"], unique: true
  t.index ["unlock_token"]
end
```

**Key Observations:**
- Uses `crypted_password` + `salt` (Sorcery convention)
- Has brute force protection fields (`failed_logins_count`, `lock_expires_at`, `unlock_token`)
- Email is the unique login identifier
- Role-based access control via enum (to be preserved with Pundit)

#### 2.1.3 Authentication Features in Use

**Features Currently Implemented:**
1. **Login/Logout** (`operator_sessions_controller.rb`):
   - Login via email + password
   - Session-based authentication
   - Redirect after login to `operator_operates_path`
   - Japanese UI messages ("キャットイン", "キャットアウト")

2. **Brute Force Protection**:
   - 5 failed attempts trigger 45-minute account lock
   - Email notification on locked account access
   - Automatic unlock after expiry period

3. **Authorization Guards**:
   - `require_login` before_action in `Operator::BaseController`
   - Custom `not_authenticated` redirect to root path

4. **Password Validation** (`operator.rb`):
   - Minimum length: 8 characters
   - Required confirmation on create/update
   - Email format validation (lowercase alphanumeric + special chars)

**Features NOT Currently Used:**
- User activation/email confirmation
- Password reset via email
- Remember me functionality
- Session timeout
- Activity logging (last_login_at, etc.)
- External OAuth providers

#### 2.1.4 Controller Structure

```
app/controllers/
├── application_controller.rb
└── operator/
    ├── base_controller.rb              # Enforces require_login
    ├── operator_sessions_controller.rb # Handles login/logout
    └── [other controllers inherit from base_controller]
```

**Key Methods Used from Sorcery:**
- `login(email, password)` - Authenticates and creates session
- `logout` - Destroys session
- `require_login` - Before action filter
- `current_user` - Implicitly available (not seen in code but Sorcery provides it)

#### 2.1.5 View Structure

**Login Form** (`app/views/operator/operator_sessions/new.html.slim`):
- Simple form with email and password fields
- Custom submit button text: "🐾 キャットイン 🐾"
- Uses `form_with url: operator_cat_in_path`

#### 2.1.6 Test Coverage

**System Tests** (`spec/system/operator_sessions_spec.rb`):
- Login success scenario
- Login failure with wrong credentials
- Logout functionality

**Test Helpers** (`spec/support/login_macros.rb`):
- `login(operator)` helper for system tests
- Hardcoded password: 'password' (factory default)

**Factory** (inferred):
- Creates operators with default password 'password'
- Must set crypted_password via Sorcery

### 2.2 Functional Requirements

**FR-1: User Authentication**
- Operators must be able to log in using email and password
- Invalid credentials must be rejected
- Sessions must persist across requests

**FR-2: Session Management**
- Login creates a secure session
- Logout destroys the session
- Sessions must be scoped to operator namespace

**FR-3: Brute Force Protection**
- Account locks after 5 consecutive failed login attempts
- Lock duration: 45 minutes
- Email notification sent on locked account access attempts
- Automatic unlock after lock period expires

**FR-4: Password Security**
- Passwords stored using secure hashing (bcrypt or better)
- Minimum password length: 8 characters
- Password confirmation required on creation/update

**FR-5: Access Control**
- Unauthenticated requests to protected pages redirect to root
- Current operator information accessible in controllers
- Role-based permissions managed by Pundit (unchanged)

**FR-6: Data Migration**
- Existing operator accounts migrate to new authentication system
- Existing passwords remain valid (no forced password reset)
- All operator attributes preserved (name, email, role, etc.)

**FR-7: Backward Compatibility**
- Existing operator credentials continue to work
- Email uniqueness constraints maintained
- Custom UI language (Japanese) preserved

### 2.2.5 Future Authentication Extension Requirements

**OAuth/Social Login Support (Planned)**:
- FR-8: System must support pluggable authentication providers
- FR-9: Database schema must accommodate OAuth credentials (provider, uid)
- FR-10: Password must be optional for OAuth-only users

**Multi-Factor Authentication Support (Planned)**:
- FR-11: Database schema must include MFA fields (secret, enabled flag, method type)
- FR-12: Authentication flow must support two-step verification
- FR-13: MFA must support TOTP (Google Authenticator) and SMS

**Authentication Provider Abstraction**:
- FR-14: Authentication logic must be abstracted to support multiple providers
- FR-15: Password provider must be one implementation of authentication interface
- FR-16: New providers must be addable without modifying existing authentication concern

### 2.3 Non-Functional Requirements

**NFR-1: Security**
- Password hashing strength: bcrypt cost factor ≥ 12 (production)
- Session tokens cryptographically secure
- Protection against timing attacks
- CSRF protection maintained
- Secure password comparison (constant-time)

**NFR-2: Performance**
- Login request completes in < 500ms (p95)
- Password verification does not cause UI lag
- Database queries optimized (indexed email lookups)

**NFR-3: Reliability**
- Zero downtime deployment
- Rollback capability if migration fails
- Data integrity verified via checksums
- Transaction safety for data migrations

**NFR-4: Maintainability**
- Rails 8 conventions followed
- Clear separation of authentication and authorization
- Comprehensive test coverage (unit + system tests)
- Documentation for future maintainers

**NFR-5: Compatibility**
- Works with MySQL 8.0 (dev/test) and PostgreSQL (production)
- Compatible with Ruby 3.4.6
- Works with existing Pundit authorization
- Compatible with existing mailer system

### 2.4 Constraints

**Technical Constraints:**
- Must use Rails 8.1.1 (already in place)
- Must use Ruby 3.4.6 (already in place)
- Cannot force password reset for existing users
- Must maintain MySQL/PostgreSQL compatibility
- Must preserve existing database records

**Business Constraints:**
- Zero downtime requirement for production
- No disruption to existing operator workflows
- Must maintain custom Japanese UI labels
- Cannot change email as login identifier

**Migration Constraints:**
- Sorcery's `crypted_password` + `salt` must convert to Rails 8's `password_digest`
- Existing bcrypt hashes must remain valid
- Cannot lose brute force protection data during migration

---

## 3. Proposed Solution Architecture

### 3.1 Rails 8 Authentication Generator

Rails 8 introduced a new authentication generator that creates:
- `Authentication` concern for controllers
- `SessionsController` for login/logout
- `PasswordsController` for password management (optional)
- Migration for `password_digest` field
- `has_secure_password` usage in models

**Command:**
```bash
bin/rails generate authentication
```

**Generated Files:**
- `app/controllers/concerns/authentication.rb`
- `app/controllers/sessions_controller.rb`
- `app/models/concerns/authenticatable.rb` (custom name for our case)
- Migration for adding `password_digest` to users
- System tests

### 3.2 Architectural Approach

**Strategy: Hybrid Migration with Dual Password Support**

We'll implement a phased migration that:
1. Adds Rails 8 authentication alongside Sorcery (transition period)
2. Migrates password hashes from Sorcery format to Rails 8 format
3. Maintains brute force protection logic
4. Removes Sorcery after verification

**Why this approach?**
- Allows gradual migration with rollback capability
- Preserves existing password hashes (same bcrypt algorithm)
- Minimizes risk of authentication failure
- Enables thorough testing before full cutover

### 3.3 Component Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Application Layer                      │
├─────────────────────────────────────────────────────────┤
│  Operator::OperatorSessionsController                   │
│    ├─ create (login)                                    │
│    ├─ destroy (logout)                                  │
│    └─ Uses: Authentication concern                      │
├─────────────────────────────────────────────────────────┤
│  Concerns::Authentication (Rails 8)                     │
│    ├─ authenticate (email, password)                    │
│    ├─ login(operator)                                   │
│    ├─ logout                                            │
│    ├─ current_operator                                  │
│    └─ require_authentication                            │
├─────────────────────────────────────────────────────────┤
│  Operator Model                                         │
│    ├─ has_secure_password (Rails 8)                     │
│    ├─ Concerns::BruteForceProtection                    │
│    │    ├─ increment_failed_logins                      │
│    │    ├─ lock_account!                                │
│    │    ├─ unlock_account!                              │
│    │    └─ locked?                                      │
│    └─ Validations (email, password, etc.)               │
├─────────────────────────────────────────────────────────┤
│  SessionMailer                                           │
│    └─ notice(operator, access_ip)                       │
├─────────────────────────────────────────────────────────┤
│  Pundit Authorization (unchanged)                       │
│    ├─ ApplicationPolicy                                 │
│    └─ [Various resource policies]                       │
└─────────────────────────────────────────────────────────┘

Database Layer:
┌─────────────────────────────────────────────────────────┐
│  operators table                                         │
│    ├─ password_digest (NEW - Rails 8)                   │
│    ├─ crypted_password (DEPRECATED - to be removed)     │
│    ├─ salt (DEPRECATED - to be removed)                 │
│    ├─ failed_logins_count                               │
│    ├─ lock_expires_at                                   │
│    ├─ unlock_token                                      │
│    ├─ email (unique index)                              │
│    ├─ name                                              │
│    └─ role (enum)                                       │
└─────────────────────────────────────────────────────────┘
```

### 3.3.1 Authentication Provider Abstraction

To support future authentication methods (OAuth, SAML, MFA, Passwordless), we introduce a provider abstraction pattern:

```
Authentication Architecture:
┌──────────────────────────────────────────────────────────────┐
│                  Authentication::Provider                     │
│                    (Abstract Interface)                       │
├──────────────────────────────────────────────────────────────┤
│  + authenticate(credentials) -> AuthResult                    │
│  + supports?(credential_type) -> Boolean                      │
└──────────────────────────────────────────────────────────────┘
                            ▲
                            │
         ┌──────────────────┴──────────────────┬────────────────┬─────────────┐
         │                                     │                │             │
┌────────┴────────┐              ┌─────────────┴──────┐  ┌──────┴──────┐  ┌──┴──────┐
│PasswordProvider│              │  OAuthProvider     │  │ MFAProvider │  │  SAML   │
│   (Rails 8)     │              │  (Future)          │  │  (Future)   │  │ (Future)│
├─────────────────┤              ├────────────────────┤  ├─────────────┤  ├─────────┤
│ authenticate()  │              │ authenticate()     │  │ verify()    │  │  ...    │
│ - email         │              │ - provider         │  │ - totp_code │  │         │
│ - password      │              │ - id_token         │  │ - sms_code  │  │         │
└─────────────────┘              └────────────────────┘  └─────────────┘  └─────────┘

Authentication Service Layer (Framework-Agnostic):
┌──────────────────────────────────────────────────────────────┐
│              AuthenticationService                            │
├──────────────────────────────────────────────────────────────┤
│  + authenticate(provider_type, **credentials) -> AuthResult   │
│  + verify_mfa(operator, code) -> Boolean                      │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                      AuthResult                               │
├──────────────────────────────────────────────────────────────┤
│  - status: :success | :failed                                 │
│  - user: Operator | nil                                       │
│  - reason: Symbol (e.g., :invalid_credentials, :account_locked│
│  + success?() -> Boolean                                      │
│  + failed?() -> Boolean                                       │
└──────────────────────────────────────────────────────────────┘
```

**Implementation:**

```ruby
# app/services/authentication/provider.rb (NEW)
module Authentication
  class Provider
    def authenticate(credentials)
      raise NotImplementedError, "#{self.class} must implement #authenticate"
    end

    def supports?(credential_type)
      raise NotImplementedError, "#{self.class} must implement #supports?"
    end
  end
end

# app/services/authentication/password_provider.rb (NEW)
module Authentication
  class PasswordProvider < Provider
    def authenticate(email:, password:)
      operator = Operator.find_by(email: email.downcase)
      return AuthResult.failed(:user_not_found) unless operator

      if operator.locked?
        return AuthResult.failed(:account_locked, user: operator)
      end

      if operator.authenticate(password)
        operator.reset_failed_logins!
        AuthResult.success(user: operator)
      else
        operator.increment_failed_logins!
        AuthResult.failed(:invalid_credentials, user: operator)
      end
    end

    def supports?(credential_type)
      credential_type == :password
    end
  end
end

# app/services/authentication_service.rb (NEW)
class AuthenticationService
  class << self
    def authenticate(provider_type, ip_address: nil, **credentials)
      provider = provider_for(provider_type)
      result = provider.authenticate(**credentials)

      if result.success? && result.user.respond_to?(:mfa_enabled?) && result.user.mfa_enabled?
        # MFA required - return pending MFA state
        return AuthResult.pending_mfa(user: result.user)
      end

      # Log authentication attempt
      log_authentication_attempt(provider_type, result, ip_address)

      result
    end

    private

    def provider_for(type)
      case type
      when :password
        Authentication::PasswordProvider.new
      when :oauth
        Authentication::OAuthProvider.new
      when :saml
        Authentication::SamlProvider.new
      else
        raise ArgumentError, "Unknown provider type: #{type}"
      end
    end

    def log_authentication_attempt(provider_type, result, ip_address)
      Rails.logger.info(
        event: 'authentication_attempt',
        provider: provider_type,
        result: result.status,
        reason: result.reason,
        ip: ip_address,
        request_id: RequestStore.store[:request_id],
        timestamp: Time.current.iso8601
      )
    end
  end
end

# app/services/auth_result.rb (NEW)
class AuthResult
  attr_reader :status, :user, :reason

  def self.success(user:)
    new(status: :success, user: user)
  end

  def self.failed(reason, user: nil)
    new(status: :failed, reason: reason, user: user)
  end

  def self.pending_mfa(user:)
    new(status: :pending_mfa, user: user)
  end

  def initialize(status:, user: nil, reason: nil)
    @status = status
    @user = user
    @reason = reason
  end

  def success?
    status == :success
  end

  def failed?
    status == :failed
  end

  def pending_mfa?
    status == :pending_mfa
  end
end
```

**Benefits of This Architecture:**
- New authentication methods can be added without modifying existing code
- Business logic separated from HTTP/framework concerns
- Testable in isolation (unit tests without Rails controllers)
- Supports CLI, API, background job contexts
- Easy to add OAuth (Google, GitHub, Facebook) in the future
- MFA can be layered on top of any authentication provider

### 3.4 Migration Flow

```
Phase 1: Preparation
  ├─ Add password_digest column
  ├─ Migrate existing password hashes
  └─ Add BruteForceProtection concern

Phase 2: Authentication Concern
  ├─ Implement Authentication concern
  ├─ Add has_secure_password to Operator
  └─ Update controller to use new auth

Phase 3: Testing & Validation
  ├─ Run comprehensive test suite
  ├─ Manual verification in staging
  └─ Performance testing

Phase 4: Cleanup
  ├─ Remove Sorcery gem
  ├─ Remove crypted_password & salt columns
  ├─ Remove Sorcery initializer
  └─ Update documentation

Phase 5: Deployment
  ├─ Deploy to production with feature flag
  ├─ Monitor authentication metrics
  ├─ Remove feature flag after validation
  └─ Remove deprecated columns
```

---

## 4. Data Model

### 4.1 Database Schema Changes

#### 4.1.1 Migration 1: Add Password Digest Column

```ruby
# db/migrate/20251124XXXXXX_add_password_digest_to_operators.rb
class AddPasswordDigestToOperators < ActiveRecord::Migration[8.1]
  def change
    add_column :operators, :password_digest, :string
    add_index :operators, :password_digest
  end
end
```

**Rationale:**
- Rails 8's `has_secure_password` expects `password_digest` field
- Added during transition period (Sorcery fields remain)
- Index added for potential future queries (e.g., password expiry checks)

#### 4.1.2 Migration 2: Migrate Password Hashes

**Challenge: Sorcery vs Rails 8 Password Storage**

- **Sorcery**: Stores `crypted_password` (bcrypt hash) and `salt` separately
- **Rails 8**: Stores `password_digest` (bcrypt hash with salt embedded)

**Key Insight: Both use bcrypt!**
- Sorcery uses bcrypt with external salt
- Rails 8 uses bcrypt with embedded salt
- bcrypt format: `$2a$[cost]$[22-char-salt][31-char-hash]`

**Migration Strategy:**

Since both use bcrypt, we need to verify if Sorcery's `crypted_password` is already in bcrypt format. If so, we can directly copy it.

**Investigation Required:**
- Check if Sorcery stores full bcrypt string or just the hash portion
- Test with sample password to compare formats

**Tentative Migration Code:**
```ruby
# db/migrate/20251124XXXXXX_migrate_sorcery_passwords.rb
class MigrateSourceryPasswords < ActiveRecord::Migration[8.1]
  def up
    # Sorcery stores bcrypt in crypted_password (with external salt)
    # Rails 8 expects bcrypt with embedded salt in password_digest

    Operator.find_each do |operator|
      if operator.crypted_password.present?
        # Sorcery's crypted_password should be a valid bcrypt hash
        # Test if it works with bcrypt directly
        operator.update_column(:password_digest, operator.crypted_password)
      end
    end
  end

  def down
    Operator.update_all(password_digest: nil)
  end
end
```

**Note:** This migration needs verification in testing phase. If Sorcery uses a different format, we'll need a custom migration strategy.

#### 4.1.3 Migration 3: Remove Sorcery Columns (Post-Verification)

```ruby
# db/migrate/20251124XXXXXX_remove_sorcery_columns_from_operators.rb
class RemoveSorceryColumnsFromOperators < ActiveRecord::Migration[8.1]
  def up
    remove_column :operators, :crypted_password
    remove_column :operators, :salt
  end

  def down
    add_column :operators, :crypted_password, :string
    add_column :operators, :salt, :string
  end
end
```

**Timing:** Only run after complete verification in production.

### 4.1.4 Migration 4: Add Multi-Factor Authentication Fields (Future)

```ruby
# db/migrate/20251124XXXXXX_add_mfa_to_operators.rb
class AddMfaToOperators < ActiveRecord::Migration[8.1]
  def change
    add_column :operators, :mfa_enabled, :boolean, default: false, null: false
    add_column :operators, :mfa_secret, :string # Encrypted TOTP secret
    add_column :operators, :mfa_method, :string # 'totp', 'sms', 'email'
    add_column :operators, :mfa_backup_codes, :text # JSON array of backup codes

    add_index :operators, :mfa_enabled
  end
end
```

**Rationale:**
- `mfa_enabled`: Feature flag per operator (gradual rollout)
- `mfa_secret`: TOTP secret for Google Authenticator (encrypted at rest)
- `mfa_method`: Supports multiple MFA methods (TOTP, SMS, Email)
- `mfa_backup_codes`: Emergency recovery codes (hashed)

**MFA Authentication Flow:**
```
1. User submits email + password
2. PasswordProvider authenticates credentials
3. If operator.mfa_enabled? → return AuthResult.pending_mfa
4. Frontend prompts for MFA code
5. User submits MFA code
6. MfaProvider.verify(operator, code)
7. If valid → create session
8. If invalid → retry with limit (3 attempts)
```

### 4.1.5 Migration 5: Add OAuth Support Fields (Future)

```ruby
# db/migrate/20251124XXXXXX_add_oauth_to_operators.rb
class AddOauthToOperators < ActiveRecord::Migration[8.1]
  def change
    add_column :operators, :oauth_provider, :string # 'google', 'github', 'facebook'
    add_column :operators, :oauth_uid, :string # Unique ID from OAuth provider
    add_column :operators, :oauth_token, :string # Encrypted access token
    add_column :operators, :oauth_refresh_token, :string # Encrypted refresh token
    add_column :operators, :oauth_expires_at, :datetime

    add_index :operators, [:oauth_provider, :oauth_uid], unique: true

    # Make password optional for OAuth-only users
    change_column_null :operators, :password_digest, true
  end
end
```

**Rationale:**
- Supports OAuth-only users (no password required)
- Stores OAuth provider and unique ID for account linking
- Stores encrypted tokens for API access (if needed)
- Composite unique index prevents duplicate OAuth accounts

### 4.2 Final Schema

```ruby
create_table "operators", force: :cascade do |t|
  # Authentication (Rails 8)
  t.string "password_digest" # NULL allowed for OAuth-only users
  t.string "email", null: false

  # Profile
  t.string "name", null: false
  t.integer "role", default: 1, null: false

  # Brute Force Protection
  t.integer "failed_logins_count", default: 0
  t.datetime "lock_expires_at"
  t.string "unlock_token"

  # Multi-Factor Authentication (Future)
  t.boolean "mfa_enabled", default: false, null: false
  t.string "mfa_secret" # Encrypted TOTP secret
  t.string "mfa_method" # 'totp', 'sms', 'email'
  t.text "mfa_backup_codes" # JSON array of hashed backup codes

  # OAuth Support (Future)
  t.string "oauth_provider" # 'google', 'github', 'facebook'
  t.string "oauth_uid" # Provider's unique user ID
  t.string "oauth_token" # Encrypted access token
  t.string "oauth_refresh_token" # Encrypted refresh token
  t.datetime "oauth_expires_at"

  # Timestamps
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  # Indexes
  t.index ["email"], unique: true
  t.index ["unlock_token"]
  t.index ["mfa_enabled"]
  t.index ["oauth_provider", "oauth_uid"], unique: true
end
```

**Changes from Current Schema:**
- ✅ Added: `password_digest` (NULL allowed for OAuth-only users)
- ❌ Removed: `crypted_password`, `salt`
- ✅ Retained: All brute force protection fields
- ✅ Retained: All profile and role fields
- ✅ Added (Future): MFA fields (`mfa_enabled`, `mfa_secret`, `mfa_method`, `mfa_backup_codes`)
- ✅ Added (Future): OAuth fields (`oauth_provider`, `oauth_uid`, `oauth_token`, `oauth_refresh_token`, `oauth_expires_at`)

### 4.3 Data Migration Validation

**Validation Steps:**

1. **Pre-Migration Checksum:**
```ruby
# Calculate checksum of all operator emails and crypted_passwords
checksums = Operator.pluck(:id, :email, :crypted_password).map do |id, email, pwd|
  Digest::SHA256.hexdigest("#{id}:#{email}:#{pwd}")
end
```

2. **Post-Migration Verification:**
```ruby
# Verify all operators have password_digest
missing = Operator.where(password_digest: nil).count
raise "Migration failed: #{missing} operators missing password_digest" if missing > 0

# Test authentication with known credentials
test_operator = Operator.find_by(email: 'test@example.com')
raise "Auth failed" unless test_operator.authenticate('test_password')
```

3. **Rollback Plan:**
- Keep Sorcery columns for 30 days post-migration
- Feature flag to switch between Sorcery and Rails 8 auth
- Automated rollback script if auth failures spike

---

## 5. API Design

### 5.1 Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_operator
    helper_method :current_operator
    helper_method :operator_signed_in?
  end

  # Authenticate operator with email and password
  # Returns operator if successful, nil otherwise
  def authenticate_operator(email, password)
    operator = Operator.find_by(email: email.downcase)
    return nil unless operator

    # Check if account is locked
    if operator.locked?
      operator.mail_notice(request.remote_ip)
      return nil
    end

    # Attempt authentication
    if operator.authenticate(password)
      operator.reset_failed_logins!
      operator
    else
      operator.increment_failed_logins!
      nil
    end
  end

  # Create session for operator
  def login(operator)
    reset_session # Prevent session fixation
    session[:operator_id] = operator.id
    @current_operator = operator
  end

  # Destroy operator session
  def logout
    reset_session
    @current_operator = nil
  end

  # Get current authenticated operator
  def current_operator
    @current_operator
  end

  # Check if operator is signed in
  def operator_signed_in?
    current_operator.present?
  end

  # Require authentication before action
  def require_authentication
    unless operator_signed_in?
      not_authenticated
    end
  end

  # Override this method in controllers
  def not_authenticated
    redirect_to operator_cat_in_path, alert: 'Please log in to continue.'
  end

  private

  def set_current_operator
    @current_operator ||= Operator.find_by(id: session[:operator_id]) if session[:operator_id]
  rescue ActiveRecord::RecordNotFound
    reset_session
    nil
  end
end
```

### 5.2 Operator Model Updates

```ruby
# app/models/operator.rb
class Operator < ApplicationRecord
  # Rails 8 authentication
  has_secure_password

  # Concerns
  include BruteForceProtection

  # Enums
  enum :role, { operator: 0, guest: 1 }

  # Validations
  validates :name, presence: true, length: { in: 2..255 }
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: /\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/ }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :role, presence: true

  # Normalize email to lowercase before validation
  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.downcase if email.present?
  end
end
```

### 5.3 Brute Force Protection Concern

```ruby
# app/models/concerns/brute_force_protection.rb
module BruteForceProtection
  extend ActiveSupport::Concern

  CONSECUTIVE_LOGIN_RETRIES_LIMIT = 5
  LOGIN_LOCK_TIME_PERIOD = 45.minutes

  # Check if account is locked
  def locked?
    lock_expires_at.present? && lock_expires_at > Time.current
  end

  # Increment failed login counter and lock if threshold reached
  def increment_failed_logins!
    increment!(:failed_logins_count)

    if failed_logins_count >= CONSECUTIVE_LOGIN_RETRIES_LIMIT
      lock_account!
    end
  end

  # Reset failed logins counter
  def reset_failed_logins!
    update_columns(
      failed_logins_count: 0,
      lock_expires_at: nil,
      unlock_token: nil
    )
  end

  # Lock account for specified period
  def lock_account!
    self.lock_expires_at = LOGIN_LOCK_TIME_PERIOD.from_now
    self.unlock_token = SecureRandom.urlsafe_base64(15)
    save(validate: false)
  end

  # Manually unlock account
  def unlock_account!
    reset_failed_logins!
  end

  # Send notification email (existing method)
  def mail_notice(access_ip)
    SessionMailer.notice(self, access_ip).deliver_later if locked?
  end
end
```

### 5.4 Sessions Controller Updates

```ruby
# app/controllers/operator/operator_sessions_controller.rb
class Operator::OperatorSessionsController < Operator::BaseController
  skip_before_action :require_authentication, only: %i[new create]

  def new
    # Render login form
  end

  def create
    operator = authenticate_operator(params[:email], params[:password])

    if operator
      login(operator)
      redirect_to operator_operates_path, success: 'キャットインしました。'
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが正しくありません。'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to operator_cat_in_path, success: 'キャットアウトしました。'
  end
end
```

### 5.5 Base Controller Updates

```ruby
# app/controllers/operator/base_controller.rb
class Operator::BaseController < ApplicationController
  include Authentication

  layout 'operator/layouts/application'
  before_action :require_authentication

  private

  def not_authenticated
    redirect_to root_path
  end

  # For Pundit - provide current user
  def pundit_user
    current_operator
  end
end
```

### 5.6 Application Controller Updates

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Pundit error handling (existing code remains)
  # ...
end
```

---

## 6. Security Considerations

### 6.1 Threat Model

**Threats Addressed:**

1. **T-1: Brute Force Password Attacks**
   - **Mitigation**: Account locking after 5 failed attempts for 45 minutes
   - **Detection**: Email notification to operator on locked account access
   - **Impact**: Reduced to negligible

2. **T-2: Session Hijacking**
   - **Mitigation**: Session reset on login (prevents fixation)
   - **Mitigation**: Secure session cookies (httponly, secure in production)
   - **Impact**: Low

3. **T-3: Timing Attacks on Password Comparison**
   - **Mitigation**: bcrypt's secure comparison (constant-time)
   - **Mitigation**: `has_secure_password` uses `BCrypt::Password.==`
   - **Impact**: Negligible

4. **T-4: Password Database Leakage**
   - **Mitigation**: bcrypt hashing with cost factor 12 (production)
   - **Mitigation**: No plaintext passwords stored
   - **Impact**: Very low (brute force on bcrypt is computationally expensive)

5. **T-5: CSRF Attacks on Login/Logout**
   - **Mitigation**: Rails CSRF protection enabled
   - **Mitigation**: Authenticity token validation on all state-changing requests
   - **Impact**: Negligible

6. **T-6: Credential Stuffing**
   - **Current Mitigation**: Email format validation (prevents common usernames)
   - **Future Enhancement**: Rate limiting at application level (not in this migration)
   - **Impact**: Low to moderate

### 6.2 Security Controls

**SC-1: Password Hashing**
- **Algorithm**: bcrypt
- **Cost Factor**:
  - Test environment: 1 (for speed)
  - Development: 12
  - Production: 12
- **Implementation**: `has_secure_password` with bcrypt gem
- **Validation**: Minimum 8 characters, confirmation required

**SC-2: Session Management**
- **Storage**: Server-side session in encrypted cookies
- **Reset**: Session reset on login (prevents fixation)
- **Expiry**: Browser session (cleared on browser close)
- **Cookie Flags**:
  - `httponly: true` (prevent XSS access)
  - `secure: true` in production (HTTPS only)
  - `same_site: :lax` (CSRF protection)

**SC-3: Brute Force Protection**
- **Threshold**: 5 consecutive failed login attempts
- **Lockout Duration**: 45 minutes
- **Unlock Mechanism**: Automatic expiry or manual unlock token
- **Notification**: Email alert to operator on locked account access

**SC-4: Input Validation**
- **Email Format**: Regex validation `/\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/`
- **Email Uniqueness**: Database constraint + application validation
- **Password Strength**: Minimum 8 characters
- **Password Confirmation**: Required on create/update

**SC-5: Authorization**
- **Layer Separation**: Authentication (login) separate from authorization (Pundit)
- **Unchanged**: All Pundit policies remain intact
- **Current User**: Provided via `pundit_user` method

### 6.3 Data Protection Measures

**DP-1: Password Migration**
- **Approach**: Direct copy of bcrypt hashes (same algorithm)
- **Validation**: Test authentication with known credentials before production
- **Rollback**: Keep Sorcery columns for 30 days post-migration
- **Monitoring**: Log authentication failures spike for 7 days post-migration

**DP-2: Session Data**
- **Minimal Storage**: Only `operator_id` in session
- **Encryption**: Rails encrypted cookies (AES-256-GCM)
- **Rotation**: Session reset on login

**DP-3: Sensitive Data in Logs**
- **Filtered Parameters**: `password`, `password_confirmation` automatically filtered by Rails
- **No Logging**: Never log password_digest or session tokens

**DP-4: Database Security**
- **No Plaintext**: No plaintext passwords in database
- **Indexed Email**: Fast lookup without exposing data
- **Constraints**: Unique email constraint prevents duplicates

### 6.4 Security Testing Plan

**ST-1: Password Verification**
- Test existing operator logins with known passwords
- Verify bcrypt cost factor in production
- Test password strength validation

**ST-2: Brute Force Protection**
- Trigger account lock with 5 failed attempts
- Verify 45-minute lockout duration
- Test email notification delivery
- Verify automatic unlock after expiry

**ST-3: Session Security**
- Test session fixation prevention (reset on login)
- Verify session expiry on logout
- Test concurrent sessions (if applicable)

**ST-4: Authorization Integration**
- Verify Pundit policies still enforce correctly
- Test role-based access (operator vs guest)
- Test unauthorized access redirects

**ST-5: Security Regression**
- Run RuboCop security checks
- Run Brakeman static analysis
- Run bundler-audit for gem vulnerabilities

### 6.5 Configuration Management

All security-sensitive parameters must be configured via environment variables, not hardcoded constants.

**Security Configuration (ENV Variables):**

```ruby
# config/initializers/authentication_config.rb
Rails.application.config.authentication = {
  # Brute Force Protection
  login_retry_limit: ENV.fetch('LOGIN_RETRY_LIMIT', '5').to_i,
  login_lock_duration: ENV.fetch('LOGIN_LOCK_DURATION', '45').to_i.minutes,

  # Password Policy
  password_min_length: ENV.fetch('PASSWORD_MIN_LENGTH', '8').to_i,
  password_require_uppercase: ENV.fetch('PASSWORD_REQUIRE_UPPERCASE', 'false') == 'true',
  password_require_number: ENV.fetch('PASSWORD_REQUIRE_NUMBER', 'false') == 'true',
  password_require_special_char: ENV.fetch('PASSWORD_REQUIRE_SPECIAL', 'false') == 'true',

  # Session Management
  session_timeout: ENV.fetch('SESSION_TIMEOUT', '30').to_i.minutes,
  session_absolute_timeout: ENV.fetch('SESSION_ABSOLUTE_TIMEOUT', '24').to_i.hours,

  # Password Hashing
  bcrypt_cost: ENV.fetch('BCRYPT_COST', Rails.env.test? ? '1' : '12').to_i,

  # Feature Flags
  oauth_enabled: ENV.fetch('AUTH_OAUTH_ENABLED', 'false') == 'true',
  mfa_enabled: ENV.fetch('AUTH_MFA_ENABLED', 'false') == 'true',
  passwordless_enabled: ENV.fetch('AUTH_PASSWORDLESS_ENABLED', 'false') == 'true',

  # OAuth Providers
  oauth_providers: ENV.fetch('OAUTH_PROVIDERS', '').split(',').map(&:strip),
  google_client_id: ENV['GOOGLE_OAUTH_CLIENT_ID'],
  google_client_secret: ENV['GOOGLE_OAUTH_CLIENT_SECRET'],
  github_client_id: ENV['GITHUB_OAUTH_CLIENT_ID'],
  github_client_secret: ENV['GITHUB_OAUTH_CLIENT_SECRET'],
}
```

**Usage in BruteForceProtection Concern:**

```ruby
# app/models/concerns/brute_force_protection.rb
module BruteForceProtection
  extend ActiveSupport::Concern

  def consecutive_login_retries_limit
    Rails.configuration.authentication[:login_retry_limit]
  end

  def login_lock_time_period
    Rails.configuration.authentication[:login_lock_duration]
  end

  # ... rest of methods
end
```

**Benefits:**
- Change security parameters without code deployment
- Different settings per environment (dev, staging, production)
- A/B testing different password policies
- Instant rollback by changing ENV variable
- Compliance-friendly (NIST, PCI-DSS requirements)

---

## 7. Error Handling

### 7.1 Error Scenarios

**E-1: Invalid Credentials**
- **Trigger**: Incorrect email or password
- **Response**: Increment failed_logins_count, render login form with error
- **Message**: "メールアドレスまたはパスワードが正しくありません。" (generic message to prevent email enumeration)
- **HTTP Status**: 422 Unprocessable Entity

**E-2: Account Locked**
- **Trigger**: Login attempt on locked account
- **Response**: Send email notification, render login form with error
- **Message**: "アカウントがロックされています。解除まで45分お待ちください。" (or time remaining)
- **HTTP Status**: 422 Unprocessable Entity

**E-3: Session Expired**
- **Trigger**: Access protected page without valid session
- **Response**: Redirect to login page
- **Message**: (Handled by flash message from controller)
- **HTTP Status**: 302 Redirect

**E-4: Database Connection Error**
- **Trigger**: Database unavailable during authentication
- **Response**: Log error, show generic error page
- **Message**: "システムエラーが発生しました。しばらくしてから再度お試しください。"
- **HTTP Status**: 500 Internal Server Error
- **Recovery**: Retry connection, alert operations team

**E-5: Password Migration Failure**
- **Trigger**: password_digest is nil for existing operator
- **Response**: Block login, alert operations team, provide manual recovery
- **Message**: "アカウントに問題が発生しました。サポートにお問い合わせください。"
- **HTTP Status**: 500 Internal Server Error
- **Recovery**: Manual password reset for affected operators

**E-6: Session Fixation Attempt**
- **Trigger**: Session ID manipulation detected
- **Response**: Reset session, redirect to login
- **Message**: "セキュリティ上の理由により、再度ログインしてください。"
- **HTTP Status**: 302 Redirect
- **Recovery**: User logs in with valid credentials

**E-7: Invalid Password Format on Registration**
- **Trigger**: Password < 8 characters or no confirmation
- **Response**: Render form with validation errors
- **Message**: ActiveRecord validation errors displayed
- **HTTP Status**: 422 Unprocessable Entity

**E-8: Email Already Taken**
- **Trigger**: Duplicate email registration
- **Response**: Render form with validation errors
- **Message**: "メールアドレスはすでに使用されています。"
- **HTTP Status**: 422 Unprocessable Entity

### 7.2 Error Messages

**User-Facing Messages (Japanese):**

```yaml
ja:
  errors:
    authentication:
      invalid_credentials: "メールアドレスまたはパスワードが正しくありません。"
      account_locked: "アカウントがロックされています。%{time}後に解除されます。"
      account_locked_permanent: "アカウントがロックされています。管理者にお問い合わせください。"
      session_expired: "セッションが切れました。再度ログインしてください。"
      system_error: "システムエラーが発生しました。しばらくしてから再度お試しください。"
      security_error: "セキュリティ上の理由により、再度ログインしてください。"

  activerecord:
    errors:
      models:
        operator:
          attributes:
            email:
              taken: "メールアドレスはすでに使用されています。"
              invalid: "メールアドレスの形式が正しくありません。"
            password:
              too_short: "パスワードは8文字以上で設定してください。"
              confirmation: "パスワードとパスワード確認が一致しません。"
```

**Technical Error Logging:**

```ruby
# Log authentication failures with context
Rails.logger.warn(
  "Authentication failed for email=#{email} from IP=#{request.remote_ip} " \
  "reason=#{reason} failed_count=#{operator.failed_logins_count}"
)

# Log account locks
Rails.logger.info(
  "Account locked for operator_id=#{operator.id} email=#{operator.email} " \
  "lock_expires_at=#{operator.lock_expires_at}"
)

# Log migration issues
Rails.logger.error(
  "Password migration failed for operator_id=#{operator.id} " \
  "crypted_password_present=#{operator.crypted_password.present?} " \
  "password_digest_present=#{operator.password_digest.present?}"
)
```

### 7.3 Recovery Strategies

**RS-1: Account Unlock Recovery**
- **Self-Service**: Wait for 45-minute expiry
- **Manual**: Admin can run `operator.unlock_account!` in console
- **Future Enhancement**: Unlock via email token (not in scope for this migration)

**RS-2: Password Reset Recovery**
- **Current**: No self-service password reset (Sorcery's reset_password module not enabled)
- **Maintained**: Continue without self-service reset (unchanged from current system)
- **Manual**: Admin can reset password in console: `operator.update(password: 'new_password')`

**RS-3: Session Recovery**
- **Strategy**: User logs in again
- **Prevention**: Clear session cookies on logout
- **Monitoring**: Track session creation/destruction metrics

**RS-4: Migration Rollback**
- **Trigger**: >5% authentication failure rate after migration
- **Action**: Feature flag to revert to Sorcery authentication
- **Code**:
```ruby
# In Authentication concern
def authenticate_operator(email, password)
  if Rails.configuration.use_sorcery_auth
    # Fallback to Sorcery
    login(email, password) # Sorcery method
  else
    # Use Rails 8 authentication
    # ... (Rails 8 code)
  end
end
```

**RS-5: Data Corruption Recovery**
- **Prevention**: Database backup before migration
- **Detection**: Checksum validation post-migration
- **Recovery**: Restore from backup, retry migration with fixes

---

## 8. Testing Strategy

### 8.1 Unit Testing

**UT-1: Operator Model Tests**

```ruby
# spec/models/operator_spec.rb
RSpec.describe Operator, type: :model do
  describe 'authentication' do
    let(:operator) { create(:operator, password: 'password123') }

    it 'authenticates with correct password' do
      expect(operator.authenticate('password123')).to eq(operator)
    end

    it 'fails authentication with incorrect password' do
      expect(operator.authenticate('wrongpassword')).to be_falsey
    end

    it 'hashes password using bcrypt' do
      expect(operator.password_digest).to start_with('$2a$')
    end
  end

  describe 'brute force protection' do
    let(:operator) { create(:operator) }

    it 'locks account after 5 failed logins' do
      5.times { operator.increment_failed_logins! }
      expect(operator.locked?).to be true
    end

    it 'sets lock expiry 45 minutes in future' do
      5.times { operator.increment_failed_logins! }
      expect(operator.lock_expires_at).to be_within(1.second).of(45.minutes.from_now)
    end

    it 'generates unlock token on lock' do
      5.times { operator.increment_failed_logins! }
      expect(operator.unlock_token).to be_present
    end

    it 'resets failed logins on successful auth' do
      operator.update(failed_logins_count: 3)
      operator.reset_failed_logins!
      expect(operator.failed_logins_count).to eq(0)
    end

    it 'unlocks account manually' do
      5.times { operator.increment_failed_logins! }
      operator.unlock_account!
      expect(operator.locked?).to be false
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_length_of(:password).is_at_least(8) }
    it { should validate_presence_of(:name) }
  end
end
```

**UT-2: Authentication Concern Tests**

```ruby
# spec/controllers/concerns/authentication_spec.rb
RSpec.describe Authentication, type: :controller do
  controller(ApplicationController) do
    include Authentication

    def index
      render plain: 'OK'
    end
  end

  let(:operator) { create(:operator, password: 'password123') }

  describe '#authenticate_operator' do
    it 'returns operator with valid credentials' do
      result = controller.authenticate_operator(operator.email, 'password123')
      expect(result).to eq(operator)
    end

    it 'returns nil with invalid credentials' do
      result = controller.authenticate_operator(operator.email, 'wrongpass')
      expect(result).to be_nil
    end

    it 'increments failed logins on invalid credentials' do
      expect {
        controller.authenticate_operator(operator.email, 'wrongpass')
      }.to change { operator.reload.failed_logins_count }.by(1)
    end

    it 'returns nil for locked account' do
      operator.lock_account!
      result = controller.authenticate_operator(operator.email, 'password123')
      expect(result).to be_nil
    end

    it 'sends email notification for locked account' do
      operator.lock_account!
      allow(controller).to receive(:request).and_return(double(remote_ip: '127.0.0.1'))

      expect {
        controller.authenticate_operator(operator.email, 'password123')
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe '#login' do
    it 'sets session operator_id' do
      controller.login(operator)
      expect(session[:operator_id]).to eq(operator.id)
    end

    it 'resets session before setting operator_id' do
      session[:old_key] = 'value'
      controller.login(operator)
      expect(session[:old_key]).to be_nil
    end

    it 'sets current_operator' do
      controller.login(operator)
      expect(controller.current_operator).to eq(operator)
    end
  end

  describe '#logout' do
    before { controller.login(operator) }

    it 'clears session' do
      controller.logout
      expect(session[:operator_id]).to be_nil
    end

    it 'clears current_operator' do
      controller.logout
      expect(controller.current_operator).to be_nil
    end
  end

  describe '#current_operator' do
    it 'returns nil when not logged in' do
      expect(controller.current_operator).to be_nil
    end

    it 'returns operator when logged in' do
      controller.login(operator)
      expect(controller.current_operator).to eq(operator)
    end

    it 'memoizes result' do
      controller.login(operator)
      expect(Operator).to receive(:find_by).once.and_return(operator)
      2.times { controller.current_operator }
    end
  end

  describe '#require_authentication' do
    it 'allows access when logged in' do
      controller.login(operator)
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'redirects when not logged in' do
      controller.class.before_action :require_authentication
      get :index
      expect(response).to have_http_status(:redirect)
    end
  end
end
```

### 8.2 Integration Testing

**IT-1: Sessions Controller Tests**

```ruby
# spec/requests/operator/operator_sessions_spec.rb
RSpec.describe 'Operator::OperatorSessions', type: :request do
  let(:operator) { create(:operator, password: 'password123') }

  describe 'POST /operator/cat_in' do
    context 'with valid credentials' do
      it 'logs in operator' do
        post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
        expect(session[:operator_id]).to eq(operator.id)
      end

      it 'redirects to operates page' do
        post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
        expect(response).to redirect_to(operator_operates_path)
      end

      it 'shows success message' do
        post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
        follow_redirect!
        expect(response.body).to include('キャットインしました')
      end

      it 'resets failed logins' do
        operator.update(failed_logins_count: 3)
        post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
        expect(operator.reload.failed_logins_count).to eq(0)
      end
    end

    context 'with invalid credentials' do
      it 'does not log in operator' do
        post operator_cat_in_path, params: { email: operator.email, password: 'wrongpass' }
        expect(session[:operator_id]).to be_nil
      end

      it 're-renders login form' do
        post operator_cat_in_path, params: { email: operator.email, password: 'wrongpass' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('メールアドレス')
      end

      it 'increments failed logins' do
        expect {
          post operator_cat_in_path, params: { email: operator.email, password: 'wrongpass' }
        }.to change { operator.reload.failed_logins_count }.by(1)
      end
    end

    context 'with locked account' do
      before { operator.lock_account! }

      it 'does not log in operator' do
        post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
        expect(session[:operator_id]).to be_nil
      end

      it 'sends notification email' do
        expect {
          post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end

  describe 'DELETE /operator/cat_out' do
    before { post operator_cat_in_path, params: { email: operator.email, password: 'password123' } }

    it 'logs out operator' do
      delete operator_cat_out_path
      expect(session[:operator_id]).to be_nil
    end

    it 'redirects to login page' do
      delete operator_cat_out_path
      expect(response).to redirect_to(operator_cat_in_path)
    end

    it 'shows success message' do
      delete operator_cat_out_path
      follow_redirect!
      expect(response.body).to include('キャットアウトしました')
    end
  end
end
```

### 8.3 System Testing

**ST-1: Full Login/Logout Flow**

```ruby
# spec/system/operator_sessions_spec.rb (updated)
RSpec.describe '[SystemTest] OperatorSessions', type: :system do
  let(:operator) { create(:operator, password: 'password123') }

  describe 'successful login flow' do
    it 'logs in and redirects to operates page' do
      visit operator_cat_in_path
      fill_in 'email', with: operator.email
      fill_in 'password', with: 'password123'
      click_button '🐾 キャットイン 🐾'

      expect(page).to have_content("Let's bring warmth to the world!!")
      expect(page).to have_current_path(operator_operates_path)
    end
  end

  describe 'failed login flow' do
    it 'shows error and stays on login page' do
      visit operator_cat_in_path
      fill_in 'email', with: operator.email
      fill_in 'password', with: 'wrongpassword'
      click_button '🐾 キャットイン 🐾'

      expect(page).not_to have_content("Let's bring warmth to the world!!")
      expect(page).to have_content('メールアドレス')
      expect(page).to have_current_path(operator_cat_in_path)
    end

    it 'locks account after 5 failed attempts' do
      visit operator_cat_in_path

      5.times do
        fill_in 'email', with: operator.email
        fill_in 'password', with: 'wrongpassword'
        click_button '🐾 キャットイン 🐾'
      end

      expect(operator.reload.locked?).to be true
    end
  end

  describe 'logout flow' do
    before do
      visit operator_cat_in_path
      fill_in 'email', with: operator.email
      fill_in 'password', with: 'password123'
      click_button '🐾 キャットイン 🐾'
    end

    it 'logs out and redirects to login page' do
      click_link 'キャットアウト'

      expect(page).to have_content('キャットアウトしました')
      expect(page).to have_content('メールアドレス')
      expect(page).to have_current_path(operator_cat_in_path)
    end
  end

  describe 'session persistence' do
    it 'maintains session across page visits' do
      visit operator_cat_in_path
      fill_in 'email', with: operator.email
      fill_in 'password', with: 'password123'
      click_button '🐾 キャットイン 🐾'

      visit operator_operates_path
      expect(page).to have_content("Let's bring warmth to the world!!")
    end

    it 'redirects to login when accessing protected page without session' do
      visit operator_operates_path
      expect(page).to have_current_path(root_path)
    end
  end
end
```

**ST-2: Password Migration Verification**

```ruby
# spec/system/password_migration_spec.rb
RSpec.describe '[SystemTest] PasswordMigration', type: :system do
  describe 'migrated passwords' do
    let!(:operator) do
      # Create operator with Sorcery-style password
      op = Operator.new(
        email: 'test@example.com',
        name: 'Test Operator',
        role: :operator
      )
      op.password = 'password123'
      op.password_confirmation = 'password123'
      op.save!

      # Simulate migration: copy crypted_password to password_digest
      # (This assumes Sorcery uses bcrypt in crypted_password)
      op.update_column(:password_digest, op.crypted_password)
      op
    end

    it 'allows login with original password' do
      visit operator_cat_in_path
      fill_in 'email', with: operator.email
      fill_in 'password', with: 'password123'
      click_button '🐾 キャットイン 🐾'

      expect(page).to have_content("Let's bring warmth to the world!!")
    end

    it 'rejects login with wrong password' do
      visit operator_cat_in_path
      fill_in 'email', with: operator.email
      fill_in 'password', with: 'wrongpassword'
      click_button '🐾 キャットイン 🐾'

      expect(page).not_to have_content("Let's bring warmth to the world!!")
    end
  end
end
```

### 8.4 Edge Cases Testing

**EC-1: Concurrent Login Attempts**
```ruby
it 'handles concurrent login attempts gracefully' do
  threads = 3.times.map do
    Thread.new do
      post operator_cat_in_path, params: { email: operator.email, password: 'wrongpass' }
    end
  end
  threads.each(&:join)

  # Should not exceed 3 failed logins
  expect(operator.reload.failed_logins_count).to eq(3)
end
```

**EC-2: Session Fixation**
```ruby
it 'prevents session fixation' do
  # Set up a session ID
  get operator_cat_in_path
  old_session_id = session.id

  # Login
  post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
  new_session_id = session.id

  # Session ID should change
  expect(new_session_id).not_to eq(old_session_id)
end
```

**EC-3: Email Case Insensitivity**
```ruby
it 'authenticates with different email case' do
  operator = create(:operator, email: 'test@example.com', password: 'password123')

  post operator_cat_in_path, params: { email: 'TEST@EXAMPLE.COM', password: 'password123' }
  expect(session[:operator_id]).to eq(operator.id)
end
```

**EC-4: Lock Expiry**
```ruby
it 'automatically unlocks account after expiry' do
  operator.lock_account!

  # Travel past lock expiry
  travel 46.minutes

  expect(operator.locked?).to be false
end
```

### 8.5 Performance Testing

**PT-1: Password Hashing Performance**
```ruby
it 'completes password authentication within acceptable time' do
  operator = create(:operator, password: 'password123')

  benchmark = Benchmark.measure do
    1000.times { operator.authenticate('password123') }
  end

  # Average should be < 50ms per auth (bcrypt cost 12)
  average_ms = (benchmark.real / 1000) * 1000
  expect(average_ms).to be < 50
end
```

**PT-2: Login Request Performance**
```ruby
it 'completes login request within acceptable time' do
  operator = create(:operator, password: 'password123')

  benchmark = Benchmark.measure do
    post operator_cat_in_path, params: { email: operator.email, password: 'password123' }
  end

  # Should complete in < 500ms
  expect(benchmark.real * 1000).to be < 500
end
```

### 8.6 Security Testing

**SEC-1: Password Strength**
```ruby
describe 'password security' do
  it 'uses bcrypt with cost factor 12 in production' do
    allow(Rails.env).to receive(:production?).and_return(true)
    operator = create(:operator, password: 'password123')

    # bcrypt format: $2a$[cost]$...
    cost = operator.password_digest.split('$')[2].to_i
    expect(cost).to eq(12)
  end

  it 'rejects passwords shorter than 8 characters' do
    operator = build(:operator, password: 'short', password_confirmation: 'short')
    expect(operator).not_to be_valid
  end
end
```

**SEC-2: Timing Attack Resistance**
```ruby
it 'uses constant-time password comparison' do
  operator = create(:operator, password: 'password123')

  # Measure time for correct password
  correct_time = Benchmark.measure do
    10000.times { operator.authenticate('password123') }
  end

  # Measure time for incorrect password
  incorrect_time = Benchmark.measure do
    10000.times { operator.authenticate('wrongpassword') }
  end

  # Times should be similar (within 10% variance)
  # This tests bcrypt's constant-time comparison
  variance = (correct_time.real - incorrect_time.real).abs / correct_time.real
  expect(variance).to be < 0.1
end
```

### 8.7 Observability Testing

**Test that logs are emitted correctly:**

```ruby
# spec/services/authentication_service_spec.rb
RSpec.describe AuthenticationService do
  describe '.authenticate' do
    it 'logs successful authentication attempts' do
      operator = create(:operator, email: 'test@example.com', password: 'password123')

      expect(Rails.logger).to receive(:info).with(hash_including(
        event: 'authentication_attempt',
        provider: :password,
        result: :success,
        ip: '127.0.0.1'
      ))

      AuthenticationService.authenticate(:password, email: 'test@example.com', password: 'password123', ip_address: '127.0.0.1')
    end

    it 'logs failed authentication attempts with reason' do
      expect(Rails.logger).to receive(:warn).with(hash_including(
        event: 'authentication_attempt',
        result: :failed,
        reason: :invalid_credentials
      ))

      AuthenticationService.authenticate(:password, email: 'wrong@example.com', password: 'wrong')
    end
  end
end
```

**Test that metrics are incremented:**

```ruby
# spec/services/authentication_service_spec.rb
it 'increments authentication failure metric' do
  allow(STATSD).to receive(:increment)

  AuthenticationService.authenticate(:password, email: 'wrong@example.com', password: 'wrong')

  expect(STATSD).to have_received(:increment).with('auth.failures', tags: ['reason:invalid_credentials'])
end
```

---

## 9. Deployment Plan

### 9.1 Pre-Deployment Checklist

**PD-1: Code Preparation**
- [ ] All migrations written and reviewed
- [ ] All controllers updated to use Authentication concern
- [ ] All models updated with has_secure_password
- [ ] BruteForceProtection concern implemented
- [ ] All tests passing (unit, integration, system)
- [ ] RuboCop checks passing
- [ ] Brakeman security scan passing
- [ ] Code review completed

**PD-2: Database Preparation**
- [ ] Backup production database
- [ ] Test migrations on staging database
- [ ] Verify migration rollback procedure
- [ ] Estimate migration execution time
- [ ] Plan for database downtime (if any)

**PD-3: Testing Verification**
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] All system tests passing
- [ ] Performance tests meeting benchmarks
- [ ] Security tests passing
- [ ] Staging environment validated

**PD-4: Monitoring Setup**
- [ ] Authentication failure metrics dashboard
- [ ] Account lock rate monitoring
- [ ] Session creation/destruction metrics
- [ ] Error rate alerts configured
- [ ] Rollback procedure documented

### 9.2 Deployment Steps

#### Phase 1: Database Migration (Low Risk)

**Step 1.1: Add password_digest Column**
```bash
# On production
bundle exec rails db:migrate:up VERSION=20251124XXXXXX_add_password_digest_to_operators

# Verify
bundle exec rails runner "puts Operator.column_names.include?('password_digest')"
# Expected: true
```

**Step 1.2: Migrate Password Hashes**
```bash
# On production
bundle exec rails db:migrate:up VERSION=20251124XXXXXX_migrate_sorcery_passwords

# Verify
bundle exec rails runner "
  missing = Operator.where(password_digest: nil).count
  puts \"Operators missing password_digest: #{missing}\"
"
# Expected: 0
```

**Step 1.3: Test Authentication with Migrated Passwords**
```bash
# On production console
bundle exec rails console production

# Test with known operator
operator = Operator.find_by(email: 'known@example.com')
operator.authenticate('known_password')
# Expected: returns operator object (not false)
```

**Rollback Procedure (if Step 1.3 fails):**
```bash
# Rollback migrations
bundle exec rails db:migrate:down VERSION=20251124XXXXXX_migrate_sorcery_passwords
bundle exec rails db:migrate:down VERSION=20251124XXXXXX_add_password_digest_to_operators

# Verify Sorcery still works
# Test login via web interface
```

#### Phase 2: Code Deployment (Medium Risk)

**Step 2.1: Deploy Code with Feature Flag**
```bash
# Set feature flag to use Sorcery (safe mode)
export USE_SORCERY_AUTH=true

# Deploy code
git pull origin main
bundle install
bundle exec rails assets:precompile
sudo systemctl restart puma

# Verify app is running
curl -I https://your-domain.com/health
```

**Step 2.2: Enable Rails 8 Authentication for Canary Traffic**
```bash
# In production console
Rails.configuration.use_sorcery_auth = false

# Monitor for 10 minutes
# Check metrics dashboard for authentication failures
```

**Step 2.3: Monitor Authentication Metrics**

```ruby
# Dashboard queries (run every 5 minutes)

# Authentication success rate
auth_success = Operator.where(
  "updated_at > ? AND failed_logins_count = 0",
  10.minutes.ago
).count

# Authentication failure rate
auth_failure = Operator.where(
  "updated_at > ? AND failed_logins_count > 0",
  10.minutes.ago
).count

failure_rate = auth_failure.to_f / (auth_success + auth_failure)
puts "Failure rate: #{(failure_rate * 100).round(2)}%"

# Alert if failure rate > 5%
```

**Step 2.4: Full Cutover (if Step 2.3 passes)**
```bash
# Remove feature flag
unset USE_SORCERY_AUTH

# Restart app
sudo systemctl restart puma

# Monitor for 1 hour
```

**Rollback Procedure (if Step 2.4 fails):**
```bash
# Re-enable Sorcery
export USE_SORCERY_AUTH=true
sudo systemctl restart puma

# Investigate failures
bundle exec rails console production
# Check error logs for authentication failures
```

#### Phase 3: Cleanup (Low Risk)

**Step 3.1: Monitor for 7 Days**
- Monitor authentication failure rates daily
- Check for spikes in account locks
- Verify email notifications sending correctly
- Review error logs for authentication issues

**Step 3.2: Remove Sorcery Gem (After 7 Days)**
```bash
# Edit Gemfile
# Remove line: gem 'sorcery'

bundle install
git commit -m "Remove Sorcery gem"
git push origin main

# Deploy
git pull origin main
bundle install
sudo systemctl restart puma
```

**Step 3.3: Remove Sorcery Columns (After 30 Days)**
```bash
# On production
bundle exec rails db:migrate:up VERSION=20251124XXXXXX_remove_sorcery_columns_from_operators

# Verify
bundle exec rails runner "
  puts Operator.column_names.include?('crypted_password') ? 'FAIL' : 'PASS'
  puts Operator.column_names.include?('salt') ? 'FAIL' : 'PASS'
"
# Expected: PASS, PASS
```

**Step 3.4: Remove Sorcery Initializer**
```bash
rm config/initializers/sorcery.rb
git commit -m "Remove Sorcery initializer"
git push origin main
```

### 9.3 Zero-Downtime Strategy

**Approach: Blue-Green Deployment with Feature Flag**

1. **Blue Environment** (Current Sorcery):
   - Remains active during migration
   - Handles all traffic initially
   - Feature flag: `USE_SORCERY_AUTH=true`

2. **Green Environment** (Rails 8 Auth):
   - Deployed with new code
   - Initially inactive (feature flag off)
   - Tested with canary traffic (1% of requests)

3. **Gradual Cutover:**
   - 0% → Rails 8 (0 hours): Feature flag on, Sorcery active
   - 1% → Rails 8 (1 hour): Canary traffic for testing
   - 10% → Rails 8 (2 hours): If no issues, expand
   - 50% → Rails 8 (4 hours): Majority of traffic
   - 100% → Rails 8 (6 hours): Full cutover

4. **Instant Rollback:**
   - Set feature flag back to `USE_SORCERY_AUTH=true`
   - No code deployment needed
   - <1 minute rollback time

**Implementation:**
```ruby
# config/initializers/feature_flags.rb
Rails.configuration.use_sorcery_auth = ENV['USE_SORCERY_AUTH'] == 'true'

# app/controllers/concerns/authentication.rb
def authenticate_operator(email, password)
  if Rails.configuration.use_sorcery_auth
    # Legacy Sorcery authentication
    sorcery_authenticate(email, password)
  else
    # Rails 8 authentication
    rails8_authenticate(email, password)
  end
end

private

def sorcery_authenticate(email, password)
  operator = login(email, password) # Sorcery method
  operator || nil
end

def rails8_authenticate(email, password)
  operator = Operator.find_by(email: email.downcase)
  return nil unless operator

  if operator.locked?
    operator.mail_notice(request.remote_ip)
    return nil
  end

  if operator.authenticate(password)
    operator.reset_failed_logins!
    operator
  else
    operator.increment_failed_logins!
    nil
  end
end
```

### 9.4 Rollback Plan

**Trigger Conditions for Rollback:**
1. Authentication failure rate > 5% for 10 minutes
2. Account lock rate > 10% for 10 minutes
3. Critical error in authentication code
4. Database migration failure
5. Session management issues

**Rollback Procedures:**

**RB-1: Immediate Rollback (Feature Flag)**
```bash
# Set feature flag to use Sorcery
export USE_SORCERY_AUTH=true

# Restart app (not required if using ENV vars in Rails)
sudo systemctl restart puma

# Verify Sorcery is active
curl -X POST https://your-domain.com/operator/cat_in \
  -d "email=test@example.com&password=testpass"
# Check logs for "Using Sorcery authentication"

# Estimated time: <1 minute
```

**RB-2: Code Rollback (if RB-1 fails)**
```bash
# Rollback to previous release
git reset --hard <previous-commit-sha>

# Reinstall dependencies
bundle install

# Restart app
sudo systemctl restart puma

# Estimated time: 5 minutes
```

**RB-3: Database Rollback (if migrations fail)**
```bash
# Rollback password migration
bundle exec rails db:migrate:down VERSION=20251124XXXXXX_migrate_sorcery_passwords

# Rollback password_digest column addition
bundle exec rails db:migrate:down VERSION=20251124XXXXXX_add_password_digest_to_operators

# Verify Sorcery columns intact
bundle exec rails runner "
  puts Operator.column_names.include?('crypted_password') ? 'OK' : 'FAIL'
"

# Estimated time: 2 minutes
```

**RB-4: Full System Rollback (worst case)**
```bash
# Restore database from backup
mysql -u root -p database_name < backup_file.sql

# Rollback code
git reset --hard <stable-commit>
bundle install

# Restart app
sudo systemctl restart puma

# Estimated time: 15 minutes
```

### 9.5 Monitoring and Validation

**Post-Deployment Metrics (Monitor for 7 Days):**

**M-1: Authentication Success Rate**
```sql
-- Target: >95% success rate
SELECT
  DATE(created_at) as date,
  COUNT(*) as total_attempts,
  SUM(CASE WHEN failed_logins_count = 0 THEN 1 ELSE 0 END) as successful,
  (SUM(CASE WHEN failed_logins_count = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as success_rate
FROM operators
WHERE updated_at > NOW() - INTERVAL 7 DAY
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

**M-2: Account Lock Rate**
```sql
-- Target: <2% lock rate
SELECT
  DATE(updated_at) as date,
  COUNT(*) as total_operators,
  SUM(CASE WHEN lock_expires_at IS NOT NULL THEN 1 ELSE 0 END) as locked,
  (SUM(CASE WHEN lock_expires_at IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as lock_rate
FROM operators
GROUP BY DATE(updated_at)
ORDER BY date DESC;
```

**M-3: Session Creation Rate**
```ruby
# Log session creations
Rails.logger.info(
  "Session created for operator_id=#{operator.id} " \
  "auth_method=#{Rails.configuration.use_sorcery_auth ? 'sorcery' : 'rails8'}"
)

# Monitor via log aggregation
# Target: Consistent with historical baseline
```

**M-4: Error Rate**
```bash
# Check Rails logs for authentication errors
tail -f log/production.log | grep "Authentication failed"

# Target: <1% error rate (excluding invalid credentials)
```

**M-5: Performance Metrics**
```ruby
# Log authentication timing
benchmark = Benchmark.measure do
  operator.authenticate(password)
end

Rails.logger.info(
  "Authentication benchmark: #{(benchmark.real * 1000).round(2)}ms " \
  "for operator_id=#{operator.id}"
)

# Target: p95 < 500ms
```

**Alert Thresholds:**
- Authentication failure rate > 5% for 10 minutes → Page on-call engineer
- Account lock rate > 10% → Alert operations team
- Error rate > 2% → Alert operations team
- p95 latency > 1000ms → Alert operations team

### 9.6 Observability Setup

#### 9.6.1 Structured Logging Configuration

**Install Lograge:**

```ruby
# Gemfile
gem 'lograge'
```

**Configure Lograge:**

```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      user_id: event.payload[:user_id],
      user_email: event.payload[:user_email],
      user_agent: event.payload[:user_agent],
      remote_ip: event.payload[:remote_ip],
      exception: event.payload[:exception],
      exception_message: event.payload[:exception_object]&.message
    }
  end

  # Add authentication-specific fields
  config.lograge.ignore_actions = ['HealthController#index']
end
```

**Add Request ID to all logs:**

```ruby
# app/controllers/concerns/authentication.rb
def authenticate_operator(email, password)
  request_id = request.request_id

  Rails.logger.tagged(request_id) do
    context = {
      event: 'authentication_attempt',
      email: email,
      ip: request.remote_ip,
      request_id: request_id,
      user_agent: request.user_agent,
      timestamp: Time.current.iso8601
    }

    # ... authentication logic
  end
end
```

#### 9.6.2 Metrics Instrumentation

**Install StatsD client:**

```ruby
# Gemfile
gem 'statsd-instrument'
```

**Configure StatsD:**

```ruby
# config/initializers/statsd.rb
require 'statsd-instrument'

StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new(
  ENV.fetch('STATSD_HOST', 'localhost'),
  ENV.fetch('STATSD_PORT', '8125').to_i
)

StatsD.prefix = 'cat_salvages.authentication'
StatsD.default_sample_rate = ENV.fetch('STATSD_SAMPLE_RATE', '1.0').to_f
```

**Instrument Authentication Service:**

```ruby
# app/services/authentication_service.rb
class AuthenticationService
  extend StatsD::Instrument

  def self.authenticate(provider_type, **credentials)
    start_time = Time.current
    result = nil

    statsd_measure('authenticate.duration', tags: ["provider:#{provider_type}"]) do
      provider = provider_for(provider_type)
      result = provider.authenticate(**credentials)
    end

    statsd_increment('authenticate.attempts', tags: [
      "provider:#{provider_type}",
      "result:#{result.status}"
    ])

    if result.failed?
      statsd_increment('authenticate.failures', tags: ["reason:#{result.reason}"])
    end

    result
  end

  statsd_measure :authenticate, 'authenticate.duration'
  statsd_count :authenticate, 'authenticate.attempts'
end
```

#### 9.6.3 Distributed Tracing (Request Correlation)

**Propagate Request ID to background jobs:**

```ruby
# app/mailers/session_mailer.rb
class SessionMailer < ApplicationMailer
  def notice(operator, access_ip)
    @operator = operator
    @access_ip = access_ip
    @request_id = RequestStore.store[:request_id]

    Rails.logger.info(
      event: 'email_notification_queued',
      operator_id: operator.id,
      email_type: 'account_locked',
      request_id: @request_id
    )

    mail(
      to: operator.email,
      subject: I18n.t('mailers.session_mailer.notice.subject'),
      headers: { 'X-Request-ID' => @request_id }
    )
  end
end
```

**Add Request ID middleware:**

```ruby
# config/application.rb
config.middleware.insert_before(
  Rails::Rack::Logger,
  RequestStore::Middleware
)
```

#### 9.6.4 Prometheus Metrics Endpoint (Future)

```ruby
# Gemfile
gem 'prometheus_exporter'
```

```ruby
# config/initializers/prometheus.rb
require 'prometheus_exporter/middleware'

Rails.application.middleware.unshift PrometheusExporter::Middleware
```

```ruby
# config/routes.rb
get '/metrics', to: 'metrics#index'

# app/controllers/metrics_controller.rb
class MetricsController < ApplicationController
  skip_before_action :require_authentication
  before_action :verify_metrics_token

  def index
    render plain: PrometheusExporter::Server::Runner.prometheus.metrics
  end

  private

  def verify_metrics_token
    authenticate_or_request_with_http_token do |token, options|
      ActiveSupport::SecurityUtils.secure_compare(
        token,
        ENV.fetch('METRICS_TOKEN')
      )
    end
  end
end
```

#### 9.6.5 Log Aggregation Strategy

**Option 1: CloudWatch Logs (AWS)**

```ruby
# Gemfile
gem 'aws-sdk-cloudwatchlogs'
```

```ruby
# config/initializers/cloudwatch_logs.rb
if Rails.env.production?
  require 'aws-sdk-cloudwatchlogs'

  client = Aws::CloudWatchLogs::Client.new(
    region: ENV.fetch('AWS_REGION'),
    credentials: Aws::ECSCredentials.new
  )

  log_group = ENV.fetch('CLOUDWATCH_LOG_GROUP')
  log_stream = "authentication-#{ENV.fetch('HOSTNAME', 'unknown')}"

  # Configure Rails logger to send to CloudWatch
  # (Implementation details omitted for brevity)
end
```

**Option 2: Papertrail**

```ruby
# Gemfile
gem 'remote_syslog_logger'
```

```ruby
# config/environments/production.rb
require 'remote_syslog_logger'

config.logger = RemoteSyslogLogger.new(
  ENV.fetch('PAPERTRAIL_HOST'),
  ENV.fetch('PAPERTRAIL_PORT').to_i,
  program: 'cat-salvages-auth'
)
```

**Log Retention Policy:**
- Development: 7 days
- Staging: 30 days
- Production: 90 days (compliance requirement)
- Archive to S3 after 90 days for 7 years

#### 9.6.6 Monitoring Dashboards

**Grafana Dashboard Configuration:**

Metrics to display:
- Authentication success rate (gauge)
- Authentication attempts per minute (graph)
- Failed authentication attempts by reason (pie chart)
- Account lock rate (gauge)
- p50/p95/p99 authentication latency (graph)
- Active sessions count (gauge)

**Alert Thresholds:**
- Authentication failure rate > 5% for 10 minutes → Page on-call engineer
- Account lock rate > 10% → Alert ops team via Slack
- p95 latency > 1000ms → Alert ops team
- Error rate > 2% → Alert ops team

---

## 10. Risks and Mitigation

### 10.1 High-Risk Items

**RISK-1: Password Hash Incompatibility**
- **Description**: Sorcery's password hashes may not be directly compatible with Rails 8's `has_secure_password`
- **Impact**: All existing operators unable to log in (catastrophic)
- **Likelihood**: Medium
- **Mitigation**:
  1. Test password migration on staging with real production data (anonymized)
  2. Verify bcrypt hash format compatibility before production migration
  3. Implement feature flag for instant rollback to Sorcery
  4. Keep Sorcery columns for 30 days post-migration
  5. Test authentication with known credentials immediately after migration
- **Contingency**: Rollback to Sorcery via feature flag, investigate hash format, implement custom migration

**RISK-2: Data Loss During Migration**
- **Description**: Database migration corrupts or loses operator data
- **Impact**: Permanent data loss, operators cannot log in (catastrophic)
- **Likelihood**: Low
- **Mitigation**:
  1. Full database backup before migration
  2. Test migrations on staging first
  3. Use database transactions for data migrations
  4. Implement checksums to verify data integrity
  5. Dry-run migration with validation checks
- **Contingency**: Restore from backup, retry migration with fixes

**RISK-3: Brute Force Protection Bypass**
- **Description**: Failed login counter or account locking mechanism fails during migration
- **Impact**: Security vulnerability, accounts vulnerable to brute force (high)
- **Likelihood**: Medium
- **Mitigation**:
  1. Implement BruteForceProtection concern with comprehensive tests
  2. Verify failed_logins_count increments correctly in tests
  3. Test account locking mechanism thoroughly
  4. Monitor account lock rate post-deployment
  5. Security audit of authentication code before deployment
- **Contingency**: Rollback to Sorcery, fix brute force protection logic, redeploy

**RISK-4: Session Management Issues**
- **Description**: Sessions not created/destroyed correctly, or session fixation vulnerabilities
- **Impact**: Users cannot stay logged in, or security vulnerability (high)
- **Likelihood**: Low
- **Mitigation**:
  1. Implement session reset on login (prevent fixation)
  2. Test session persistence across requests
  3. Test logout clears session completely
  4. Security test for session fixation
  5. Monitor session creation/destruction metrics
- **Contingency**: Rollback to Sorcery, fix session management, redeploy

### 10.2 Medium-Risk Items

**RISK-5: Performance Degradation**
- **Description**: Password authentication slower than Sorcery
- **Impact**: Login requests exceed 500ms, poor user experience (medium)
- **Likelihood**: Low
- **Mitigation**:
  1. Use bcrypt cost factor 12 (same as production standard)
  2. Performance test authentication with 1000 iterations
  3. Monitor p95 latency post-deployment
  4. Optimize database queries (indexed email lookups)
- **Contingency**: Reduce bcrypt cost factor to 11 (if necessary), optimize authentication flow

**RISK-6: Email Notification Failure**
- **Description**: Locked account notifications not sent
- **Impact**: Operators not notified of suspicious activity (medium)
- **Likelihood**: Low
- **Mitigation**:
  1. Preserve SessionMailer.notice method
  2. Test email delivery in integration tests
  3. Monitor ActionMailer delivery queue
  4. Verify emails sent in staging environment
- **Contingency**: Fix mailer integration, redeploy

**RISK-7: Authorization Regression**
- **Description**: Pundit policies fail due to authentication changes
- **Impact**: Access control broken, security vulnerability (high)
- **Likelihood**: Very Low
- **Mitigation**:
  1. Keep `pundit_user` method unchanged (returns current_operator)
  2. Test all Pundit policies post-migration
  3. Run full test suite including authorization tests
  4. Manual verification of role-based access in staging
- **Contingency**: Fix pundit_user integration, redeploy

**RISK-8: Japanese UI Regression**
- **Description**: Custom Japanese labels ("キャットイン", "キャットアウト") lost
- **Impact**: User confusion, branding inconsistency (low)
- **Likelihood**: Very Low
- **Mitigation**:
  1. Preserve custom button text in views
  2. Preserve custom flash messages in controllers
  3. Manual UI testing in staging
  4. Visual regression testing (screenshots)
- **Contingency**: Restore custom labels from git history

### 10.3 Low-Risk Items

**RISK-9: Test Suite Failures**
- **Description**: Existing tests fail with Rails 8 authentication
- **Impact**: Delayed deployment, need to update tests (low)
- **Likelihood**: Medium
- **Mitigation**:
  1. Update factories to use `password` instead of Sorcery-specific attributes
  2. Update login_macros helper for new authentication
  3. Run full test suite before deployment
  4. Fix failing tests incrementally
- **Contingency**: Fix tests, delay deployment if necessary

**RISK-10: Documentation Gaps**
- **Description**: Future maintainers don't understand Rails 8 authentication
- **Impact**: Slower onboarding, potential bugs (low)
- **Likelihood**: Low
- **Mitigation**:
  1. Update README with authentication overview
  2. Add inline comments to Authentication concern
  3. Document BruteForceProtection concern
  4. Create migration summary document
- **Contingency**: Write documentation post-deployment

**RISK-11: Gradual Migration Complexity**
- **Description**: Feature flag approach adds code complexity
- **Impact**: Harder to maintain, potential bugs (low)
- **Likelihood**: Low
- **Mitigation**:
  1. Keep feature flag code simple and well-tested
  2. Remove feature flag code after 30 days
  3. Document feature flag usage clearly
  4. Monitor metrics to ensure safe removal
- **Contingency**: Keep feature flag longer if needed for confidence

### 10.4 Risk Matrix

| Risk ID | Description | Impact | Likelihood | Severity | Mitigation Priority |
|---------|-------------|--------|------------|----------|---------------------|
| RISK-1 | Password hash incompatibility | Catastrophic | Medium | Critical | P0 |
| RISK-2 | Data loss during migration | Catastrophic | Low | Critical | P0 |
| RISK-3 | Brute force protection bypass | High | Medium | High | P1 |
| RISK-4 | Session management issues | High | Low | High | P1 |
| RISK-5 | Performance degradation | Medium | Low | Medium | P2 |
| RISK-6 | Email notification failure | Medium | Low | Medium | P2 |
| RISK-7 | Authorization regression | High | Very Low | Medium | P1 |
| RISK-8 | Japanese UI regression | Low | Very Low | Low | P3 |
| RISK-9 | Test suite failures | Low | Medium | Low | P3 |
| RISK-10 | Documentation gaps | Low | Low | Low | P3 |
| RISK-11 | Gradual migration complexity | Low | Low | Low | P3 |

---

## 11. Success Metrics

### 11.1 Functional Metrics

**FM-1: Authentication Success Rate**
- **Target**: ≥95% success rate for valid credentials
- **Measurement**: `successful_logins / total_login_attempts`
- **Baseline**: Current Sorcery success rate (establish before migration)

**FM-2: Zero Forced Password Resets**
- **Target**: 0 operators required to reset passwords
- **Measurement**: Count of support tickets for password resets post-migration
- **Baseline**: Normal password reset rate

**FM-3: Brute Force Protection Effectiveness**
- **Target**: 100% of accounts locked after 5 failed attempts
- **Measurement**: Test with automated script, verify all accounts lock
- **Baseline**: Sorcery brute force protection

**FM-4: Session Persistence**
- **Target**: 100% of sessions persist across requests
- **Measurement**: Automated test navigating multiple pages after login
- **Baseline**: Current session behavior

### 11.2 Technical Metrics

**TM-1: Sorcery Gem Removal**
- **Target**: Sorcery gem completely removed from Gemfile
- **Measurement**: `bundle list | grep sorcery` returns empty
- **Timeline**: Complete within 7 days post-migration

**TM-2: Test Coverage**
- **Target**: ≥95% test coverage for authentication code
- **Measurement**: SimpleCov coverage report
- **Baseline**: Current test coverage

**TM-3: Code Quality**
- **Target**: 0 RuboCop offenses in authentication code
- **Measurement**: `bundle exec rubocop app/controllers/concerns/authentication.rb`
- **Baseline**: Current RuboCop compliance

**TM-4: Security Scan**
- **Target**: 0 Brakeman warnings for authentication
- **Measurement**: `bundle exec brakeman -A | grep authentication`
- **Baseline**: Current Brakeman clean state

### 11.3 Performance Metrics

**PM-1: Login Request Latency**
- **Target**: p95 < 500ms
- **Measurement**: Application performance monitoring (APM)
- **Baseline**: Current Sorcery login latency

**PM-2: Password Verification Time**
- **Target**: Average < 100ms
- **Measurement**: Benchmark in unit tests
- **Baseline**: bcrypt with cost factor 12

**PM-3: Database Query Count**
- **Target**: ≤2 queries per login (1 find_by email, 1 update for failed_logins)
- **Measurement**: Rails query log or APM
- **Baseline**: Current Sorcery query count

### 11.4 Security Metrics

**SM-1: Password Hash Strength**
- **Target**: bcrypt cost factor ≥12 in production
- **Measurement**: Verify password_digest format in database
- **Baseline**: Sorcery bcrypt cost factor

**SM-2: Account Lock Rate**
- **Target**: <2% of operators locked per day
- **Measurement**: `locked_operators / total_operators`
- **Baseline**: Current Sorcery lock rate

**SM-3: Email Notification Delivery**
- **Target**: 100% of locked account access attempts send email
- **Measurement**: ActionMailer delivery logs
- **Baseline**: Current SessionMailer delivery rate

### 11.5 Business Metrics

**BM-1: Zero Downtime Deployment**
- **Target**: 0 minutes downtime during migration
- **Measurement**: Uptime monitoring service
- **Baseline**: 99.9% uptime SLA

**BM-2: Support Ticket Volume**
- **Target**: No increase in authentication-related support tickets
- **Measurement**: Support ticket tracking system
- **Baseline**: Normal authentication ticket volume

**BM-3: User Satisfaction**
- **Target**: No user complaints about login issues
- **Measurement**: User feedback monitoring
- **Baseline**: Current user satisfaction

### 11.5 Observability Metrics

**Logging Metrics:**
- LM-1: 100% of authentication attempts logged with request_id
- LM-2: 100% of account locks logged with reason and IP
- LM-3: 100% of email notifications logged with correlation ID
- LM-4: All logs in structured JSON format (parseable by log aggregation tools)
- LM-5: Request ID propagated to all async operations (emails, jobs)

**Performance Metrics:**
- PM-1: Authentication request → log emission < 10ms
- PM-2: Metrics emission does not add > 5ms overhead
- PM-3: Log aggregation delay < 30 seconds (CloudWatch/Papertrail)

**Monitoring Coverage:**
- MC-1: Authentication success/failure rates tracked in real-time
- MC-2: Dashboards updated every 1 minute (not every 5 minutes via DB polling)
- MC-3: Alerts trigger within 1 minute of threshold breach
- MC-4: Health check endpoint responds < 100ms

---

## 12. Timeline and Effort Estimation

### 12.1 Development Phase

| Task | Estimated Effort | Dependencies |
|------|------------------|--------------|
| Design document review | 1 day | None |
| Password migration research (bcrypt compatibility) | 2 days | None |
| Database migrations (add password_digest, migrate hashes) | 2 days | Research complete |
| Authentication concern implementation | 3 days | None |
| BruteForceProtection concern implementation | 2 days | None |
| Controller updates (sessions, base) | 1 day | Concerns complete |
| Model updates (Operator) | 1 day | Concerns complete |
| Unit tests (model, concerns) | 3 days | Implementation complete |
| Integration tests (controllers) | 2 days | Implementation complete |
| System tests (full flows) | 2 days | Integration tests complete |
| **Total Development** | **19 days** | |

### 12.2 Testing Phase

| Task | Estimated Effort | Dependencies |
|------|------------------|--------------|
| Staging environment setup | 1 day | Development complete |
| Staging database migration | 0.5 days | Staging setup |
| Functional testing on staging | 2 days | Staging migration |
| Performance testing | 1 day | Functional tests pass |
| Security testing (Brakeman, manual review) | 1 day | Functional tests pass |
| User acceptance testing (UAT) | 2 days | All tests pass |
| Bug fixes from testing | 3 days | UAT complete |
| **Total Testing** | **10.5 days** | |

### 12.3 Deployment Phase

| Task | Estimated Effort | Dependencies |
|------|------------------|--------------|
| Production database backup | 0.5 days | Pre-deployment checklist |
| Database migrations (production) | 0.5 days | Backup complete |
| Code deployment with feature flag | 0.5 days | Migrations complete |
| Canary testing (1% traffic) | 1 day | Code deployed |
| Gradual rollout (10%, 50%, 100%) | 2 days | Canary successful |
| Monitoring period (7 days) | 7 days | Full rollout |
| Sorcery gem removal | 0.5 days | 7-day monitoring complete |
| Sorcery column removal | 0.5 days | 30-day monitoring complete |
| **Total Deployment** | **12.5 days** | |

### 12.4 Total Timeline

| Phase | Duration | Calendar Time (with buffer) |
|-------|----------|------------------------------|
| Development | 19 days | 4 weeks |
| Testing | 10.5 days | 2 weeks |
| Deployment | 12.5 days | 3 weeks (including monitoring) |
| **Total** | **42 days** | **9 weeks** |

**Note**: Timeline assumes 1 developer working full-time. Parallelization possible for testing phase.

### 12.5 Critical Path

```
Design Review → Password Research → Migrations → Concerns → Controllers →
Unit Tests → Integration Tests → System Tests → Staging → UAT →
Production Deployment → Monitoring → Cleanup
```

**Potential Bottlenecks:**
1. Password migration research (if Sorcery format incompatible)
2. Bug fixes from UAT (if major issues found)
3. 7-day monitoring period (cannot be shortened for safety)

---

## 13. Reusability Guidelines

### 13.1 Reusable Components

The following components are designed for reuse across different models and contexts:

#### 13.1.1 Authentication Service (Framework-Agnostic)

**Purpose:** Authenticate users via any provider (password, OAuth, SAML, MFA)

**Reusable for:**
- Admin model authentication
- Customer model authentication
- API authentication (token-based)
- CLI tools
- Background jobs

**Usage:**

```ruby
# For Operator model
result = AuthenticationService.authenticate(:password, email: 'op@example.com', password: 'secret')

# For Admin model (future)
result = AuthenticationService.authenticate(:password, email: 'admin@example.com', password: 'secret')

# For OAuth (future)
result = AuthenticationService.authenticate(:oauth, provider: 'google', id_token: token)
```

#### 13.1.2 BruteForceProtection Concern (Parameterized)

**Purpose:** Protect any user model from brute force attacks

**Reusable for:**
- Operator model
- Admin model
- Customer model
- Any model with authentication

**Configuration:**

```ruby
# app/models/operator.rb
class Operator < ApplicationRecord
  include BruteForceProtection

  self.lock_retry_limit = 5
  self.lock_duration = 45.minutes
  self.lock_notifier = ->(operator, ip) { SessionMailer.notice(operator, ip).deliver_later }
end

# app/models/admin.rb (future)
class Admin < ApplicationRecord
  include BruteForceProtection

  self.lock_retry_limit = 3 # Stricter for admins
  self.lock_duration = 60.minutes
  self.lock_notifier = ->(admin, ip) { AdminMailer.account_locked(admin, ip).deliver_later }
end
```

### 13.2 I18n Extraction

All user-facing messages must use I18n keys, not hardcoded Japanese strings.

**Before (Hardcoded):**

```ruby
flash[:success] = "🐾 キャットイン 🐾"
flash[:alert] = "ログインに失敗しました"
```

**After (I18n):**

```ruby
flash[:success] = t('operator.sessions.login_success')
flash[:alert] = t('operator.sessions.login_failure')
```

**Locale File:**

```yaml
# config/locales/ja.yml
ja:
  operator:
    sessions:
      login_success: "🐾 キャットイン 🐾"
      login_failure: "ログインに失敗しました"
      account_locked: "アカウントがロックされています。45分後に再試行してください。"
      logout_success: "🐾 キャットアウト 🐾"
  authentication:
    errors:
      invalid_credentials: "メールアドレスまたはパスワードが正しくありません"
      account_locked: "アカウントがロックされています"
      user_not_found: "ユーザーが見つかりません"
      mfa_required: "多要素認証コードを入力してください"
      mfa_invalid: "認証コードが正しくありません"

# config/locales/en.yml
en:
  operator:
    sessions:
      login_success: "🐾 Login Successful 🐾"
      login_failure: "Login failed"
      account_locked: "Account is locked. Please try again in 45 minutes."
      logout_success: "🐾 Logged Out 🐾"
  authentication:
    errors:
      invalid_credentials: "Invalid email or password"
      account_locked: "Account is locked"
      user_not_found: "User not found"
      mfa_required: "Please enter your MFA code"
      mfa_invalid: "Invalid MFA code"
```

### 13.3 Multi-Model Authentication Pattern

**Usage for future Admin Controllers:**

```ruby
# app/controllers/admin/base_controller.rb (future)
class Admin::BaseController < ApplicationController
  include Authenticatable
  authenticates_with model: Admin, path_prefix: 'admin'

  before_action :require_authentication

  # Same interface, different model!
end
```

### 13.4 Porting Guide

**To reuse authentication for Customer model:**

1. Add password_digest to customers table
2. Include `BruteForceProtection` concern in Customer model
3. Configure lock settings and notifier
4. Create CustomerSessionsController
5. Include `Authenticatable` concern
6. Call `authenticates_with model: Customer`

**Estimated effort:** 2-3 hours

**To add OAuth provider:**

1. Implement `Authentication::GoogleOAuthProvider` (inherit from `Authentication::Provider`)
2. Add OAuth fields to operators table (migration already designed)
3. Configure OAuth credentials in ENV
4. Add OAuth callback route
5. Update UI with "Sign in with Google" button
6. Set feature flag `AUTH_OAUTH_ENABLED=true`

**Estimated effort:** 1-2 days

---

## 14. Assumptions and Dependencies

### 14.1 Assumptions

**A-1: Password Hash Compatibility**
- Assumption: Sorcery's `crypted_password` uses standard bcrypt format compatible with `has_secure_password`
- Validation: Test on staging with real production data (anonymized)
- Risk: If incompatible, need custom migration strategy

**A-2: No Active User Sessions During Migration**
- Assumption: Database migrations can run without disrupting active sessions
- Validation: Test on staging with simulated active sessions
- Risk: Sessions may be invalidated, requiring re-login

**A-3: Bcrypt Gem Version Compatibility**
- Assumption: Rails 8's bcrypt gem version is compatible with Sorcery's bcrypt version
- Validation: Check `Gemfile.lock` for bcrypt version
- Risk: Version mismatch could cause authentication failures

**A-4: No Additional Sorcery Features Needed**
- Assumption: Only core authentication and brute_force_protection are in use
- Validation: Review Sorcery configuration in `config/initializers/sorcery.rb`
- Risk: Missing features would need manual implementation

**A-5: Session Storage Unchanged**
- Assumption: Rails session storage mechanism remains the same (encrypted cookies)
- Validation: Test session persistence after migration
- Risk: Session format change could invalidate existing sessions

**A-6: Operator Model is Only Authenticated Model**
- Assumption: No other models use Sorcery authentication (e.g., no User model)
- Validation: Search codebase for `authenticates_with_sorcery!`
- Risk: Multiple models would need separate migration

**A-7: No External Authentication Providers**
- Assumption: No OAuth or external authentication in use
- Validation: Sorcery config shows no external providers enabled
- Risk: External auth would need separate migration strategy

**A-8: Database Supports Required Schema Changes**
- Assumption: MySQL 8.0 and PostgreSQL support string columns for password_digest
- Validation: Standard Rails migration should work
- Risk: Very low, standard Rails feature

### 14.2 Dependencies

**D-1: Rails 8.1.1**
- Current Status: ✅ Already upgraded (per Gemfile)
- Required: Rails 8+ for `has_secure_password` improvements
- Blocker: No (already met)

**D-2: Ruby 3.4.6**
- Current Status: ✅ Already upgraded (per Gemfile)
- Required: Ruby 3.0+ for Rails 8
- Blocker: No (already met)

**D-3: bcrypt Gem**
- Current Status: Likely present (used by Sorcery)
- Required: bcrypt gem for `has_secure_password`
- Action: Verify in Gemfile, add if missing
- Blocker: Low

**D-4: Database (MySQL 8.0 / PostgreSQL)**
- Current Status: ✅ MySQL 8.0 (dev/test), PostgreSQL (production)
- Required: Any Rails-supported database
- Blocker: No

**D-5: Pundit Gem**
- Current Status: ✅ Present in Gemfile
- Required: For authorization (unchanged)
- Impact: Must ensure `pundit_user` compatibility
- Blocker: No

**D-6: ActionMailer / Letter Opener**
- Current Status: ✅ SessionMailer exists, letter_opener_web configured
- Required: For locked account notifications
- Impact: Preserve SessionMailer.notice functionality
- Blocker: No

**D-7: RSpec Test Framework**
- Current Status: ✅ Present in Gemfile, test suite exists
- Required: For comprehensive testing strategy
- Impact: Update test helpers and factories
- Blocker: No

**D-8: Staging Environment**
- Current Status: Unknown (not mentioned in codebase)
- Required: For testing before production deployment
- Action: Set up staging environment if not exists
- Blocker: Medium (can test locally, but staging recommended)

**D-9: Database Backup Infrastructure**
- Current Status: Unknown
- Required: For safe production migration with rollback capability
- Action: Verify backup procedures before production deployment
- Blocker: High (do not migrate production without backups)

**D-10: Monitoring/Alerting System**
- Current Status: Prometheus metrics endpoint exists (`/metrics`)
- Required: For post-deployment monitoring
- Action: Configure authentication metrics and alerts
- Blocker: Low (can monitor manually initially)

### 13.3 External Dependencies

**ED-1: No Forced Password Reset Requirement**
- Dependency: Business approval to migrate passwords without reset
- Status: Assumed approved (no security mandate for reset)
- Blocker: High if not approved (would require different migration strategy)

**ED-2: Acceptable Downtime Window**
- Dependency: Business approval for deployment window
- Status: Zero downtime required (per design goals)
- Blocker: No (using feature flag approach)

**ED-3: No Active Development on Authentication**
- Dependency: No parallel work on authentication features
- Status: Unknown
- Risk: Merge conflicts if other developers working on auth
- Mitigation: Coordinate with team, use feature branch

---

## 14. Open Questions

### 14.1 Technical Questions

**Q-1: Sorcery Password Hash Format**
- Question: Does Sorcery store the full bcrypt hash in `crypted_password`, or only a portion?
- Impact: Critical for migration strategy
- Resolution: Test with sample operator on staging, inspect database directly
- Owner: Developer
- Due: Before development begins

**Q-2: Session Storage Mechanism**
- Question: Are sessions stored in cookies or database?
- Impact: Determines if session reset affects all users
- Resolution: Review `config/initializers/session_store.rb`
- Owner: Developer
- Due: Before development begins

**Q-3: Production Database Backup Schedule**
- Question: How frequently are production databases backed up?
- Impact: Determines rollback capability
- Resolution: Check with DevOps/infrastructure team
- Owner: DevOps
- Due: Before deployment planning

**Q-4: Staging Environment Availability**
- Question: Is a staging environment available with production-like data?
- Impact: Determines testing approach
- Resolution: Check with infrastructure team
- Owner: DevOps
- Due: Before testing phase

**Q-5: bcrypt Cost Factor in Current System**
- Question: What is the current bcrypt cost factor used by Sorcery in production?
- Impact: Performance expectations for Rails 8 auth
- Resolution: Inspect `config/initializers/sorcery.rb` for stretches configuration
- Owner: Developer
- Due: Before development begins

### 14.2 Business Questions

**B-1: Acceptable Deployment Timeline**
- Question: Is a 9-week timeline acceptable for this migration?
- Impact: Resource allocation and planning
- Resolution: Discuss with product/project manager
- Owner: Project Manager
- Due: After design review

**B-2: Password Reset Policy**
- Question: Should we require operators to reset passwords post-migration for security?
- Impact: User experience and security posture
- Resolution: Discuss with security team and product manager
- Owner: Security Team
- Due: Before migration strategy finalized

**B-3: Custom UI Labels**
- Question: Should we maintain custom Japanese labels ("キャットイン", "キャットアウト")?
- Impact: User experience and branding
- Resolution: Confirm with product/UX team
- Owner: Product Manager
- Due: Before view updates

**B-4: Support Team Readiness**
- Question: Does support team need training on new authentication system?
- Impact: Support ticket resolution time
- Resolution: Discuss with support team manager
- Owner: Support Manager
- Due: Before deployment

### 14.3 Process Questions

**P-1: Code Review Requirements**
- Question: Who needs to review and approve this migration code?
- Impact: Timeline and approval process
- Resolution: Check with team lead
- Owner: Team Lead
- Due: Before development begins

**P-2: Security Audit Requirement**
- Question: Is a formal security audit required before production deployment?
- Impact: Timeline and budget
- Resolution: Check with security team
- Owner: Security Team
- Due: Before deployment planning

**P-3: Change Management Process**
- Question: What is the change management approval process for production deployments?
- Impact: Deployment timeline
- Resolution: Check with operations team
- Owner: Operations
- Due: Before deployment planning

**P-4: Monitoring and Alerting Setup**
- Question: Who is responsible for setting up authentication monitoring/alerts?
- Impact: Post-deployment observability
- Resolution: Coordinate with DevOps/SRE team
- Owner: DevOps
- Due: Before deployment

---

## 15. Appendix

### 15.1 Sorcery to Rails 8 Feature Mapping

| Sorcery Feature | Rails 8 Equivalent | Implementation |
|-----------------|-------------------|----------------|
| `authenticates_with_sorcery!` | `has_secure_password` | Model macro |
| `login(email, password)` | `operator.authenticate(password)` | Custom concern method |
| `logout` | `reset_session` | Custom concern method |
| `current_user` | `current_operator` | Custom concern method |
| `require_login` | `require_authentication` | Custom concern method |
| `:brute_force_protection` | `BruteForceProtection` concern | Custom implementation |
| `failed_logins_count` | Same | Retained column |
| `lock_expires_at` | Same | Retained column |
| `unlock_token` | Same | Retained column |
| `crypted_password` | `password_digest` | Migration required |
| `salt` | (embedded in password_digest) | Migration removes column |

### 15.2 bcrypt Hash Format Reference

**Sorcery (assumed format):**
```
crypted_password: $2a$12$[22-char-salt][31-char-hash]
salt: [external-salt] (may or may not be used)
```

**Rails 8 has_secure_password:**
```
password_digest: $2a$12$[22-char-salt][31-char-hash]
```

**Format Breakdown:**
- `$2a$` - bcrypt algorithm identifier
- `12` - cost factor (number of iterations = 2^12)
- `[22-char-salt]` - base64-encoded salt (16 bytes)
- `[31-char-hash]` - base64-encoded hash (23 bytes)

**Key Point:** If Sorcery stores the full bcrypt string in `crypted_password`, migration is straightforward (direct copy). If Sorcery uses external salt separately, need custom migration logic.

### 15.3 Rails 8 Authentication Generator Output

**Expected Generated Files:**
```
app/
  controllers/
    concerns/
      authentication.rb       # Session management
    sessions_controller.rb    # Login/logout (we customize this)
  models/
    concerns/
      authenticatable.rb      # Optional, we use has_secure_password directly
db/
  migrate/
    XXXXXX_add_password_digest_to_users.rb  # We adapt for operators
spec/
  system/
    sessions_spec.rb          # We adapt for our custom flow
```

**Note:** We'll adapt the generated code to match our existing structure (Operator namespace, custom routes, Japanese UI).

### 15.4 Sample Migration Validation Script

```ruby
# script/validate_password_migration.rb
#
# Run after password migration to validate all operators can authenticate
#
# Usage: bundle exec rails runner script/validate_password_migration.rb

require 'csv'

# Test data: CSV with email,password pairs (known test accounts)
TEST_ACCOUNTS = [
  { email: 'test1@example.com', password: 'password123' },
  { email: 'test2@example.com', password: 'password456' },
  # Add more test accounts...
]

def validate_password_migration
  results = []

  TEST_ACCOUNTS.each do |account|
    operator = Operator.find_by(email: account[:email])

    if operator.nil?
      results << { email: account[:email], status: 'NOT_FOUND', message: 'Operator not found' }
      next
    end

    if operator.password_digest.nil?
      results << { email: account[:email], status: 'MIGRATION_FAILED', message: 'password_digest is nil' }
      next
    end

    if operator.authenticate(account[:password])
      results << { email: account[:email], status: 'SUCCESS', message: 'Authentication successful' }
    else
      results << { email: account[:email], status: 'AUTH_FAILED', message: 'Authentication failed with known password' }
    end
  end

  # Print results
  puts "\n=== Password Migration Validation Results ===\n"
  results.each do |result|
    puts "#{result[:email]}: #{result[:status]} - #{result[:message]}"
  end

  # Summary
  success_count = results.count { |r| r[:status] == 'SUCCESS' }
  total_count = results.count

  puts "\n=== Summary ==="
  puts "Total tested: #{total_count}"
  puts "Successful: #{success_count}"
  puts "Failed: #{total_count - success_count}"

  if success_count == total_count
    puts "\n✅ All validations passed!"
    exit 0
  else
    puts "\n❌ Some validations failed!"
    exit 1
  end
end

validate_password_migration
```

### 15.5 Feature Flag Implementation Example

```ruby
# config/initializers/feature_flags.rb
module FeatureFlags
  def self.use_sorcery_auth?
    ENV.fetch('USE_SORCERY_AUTH', 'false') == 'true'
  end

  def self.use_rails8_auth?
    !use_sorcery_auth?
  end
end

# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_operator
    helper_method :current_operator, :operator_signed_in?
  end

  def authenticate_operator(email, password)
    if FeatureFlags.use_sorcery_auth?
      sorcery_authenticate(email, password)
    else
      rails8_authenticate(email, password)
    end
  end

  private

  def sorcery_authenticate(email, password)
    operator = login(email, password) # Sorcery method

    if operator
      Rails.logger.info("Sorcery auth successful for #{email}")
      operator
    else
      Rails.logger.info("Sorcery auth failed for #{email}")
      accessed_account = Operator.find_by(email: email)
      accessed_account&.mail_notice(request.remote_ip)
      nil
    end
  end

  def rails8_authenticate(email, password)
    operator = Operator.find_by(email: email.downcase)
    return nil unless operator

    if operator.locked?
      operator.mail_notice(request.remote_ip)
      Rails.logger.info("Rails 8 auth blocked (locked) for #{email}")
      return nil
    end

    if operator.authenticate(password)
      operator.reset_failed_logins!
      Rails.logger.info("Rails 8 auth successful for #{email}")
      operator
    else
      operator.increment_failed_logins!
      Rails.logger.info("Rails 8 auth failed for #{email}")
      nil
    end
  end
end
```

### 15.6 Monitoring Dashboard Queries

```ruby
# config/prometheus/authentication_metrics.rb
#
# Custom Prometheus metrics for authentication monitoring
#
require 'prometheus/client'

prometheus = Prometheus::Client.registry

# Counter: Total login attempts
AUTH_ATTEMPTS = prometheus.counter(
  :authentication_attempts_total,
  docstring: 'Total number of authentication attempts',
  labels: [:method, :result]
)

# Counter: Account locks
ACCOUNT_LOCKS = prometheus.counter(
  :account_locks_total,
  docstring: 'Total number of account locks'
)

# Histogram: Authentication duration
AUTH_DURATION = prometheus.histogram(
  :authentication_duration_seconds,
  docstring: 'Time spent authenticating',
  labels: [:method],
  buckets: [0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

# Usage in Authentication concern:
def authenticate_operator(email, password)
  method_label = FeatureFlags.use_sorcery_auth? ? 'sorcery' : 'rails8'

  result = nil
  duration = Benchmark.measure do
    result = if FeatureFlags.use_sorcery_auth?
      sorcery_authenticate(email, password)
    else
      rails8_authenticate(email, password)
    end
  end

  # Record metrics
  AUTH_DURATION.observe(duration.real, labels: { method: method_label })
  AUTH_ATTEMPTS.increment(labels: {
    method: method_label,
    result: result ? 'success' : 'failure'
  })

  result
end
```

---

**End of Design Document**

**Next Steps:**
1. Review this design document with team
2. Address open questions
3. Get approval to proceed to Phase 2 (Planning Gate)
4. Create task plan for implementation

**Document Version**: 1.0
**Status**: Ready for Review
**Reviewers**: Engineering Team, Security Team, Product Manager
