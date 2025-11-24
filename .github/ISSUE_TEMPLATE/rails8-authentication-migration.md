# [FEAT-AUTH-001] Migrate from Sorcery to Rails 8 Built-in Authentication

## 📋 Overview

Migrate from the unmaintained Sorcery gem to Rails 8's built-in authentication system (`has_secure_password`) while preserving all existing functionality, user data, and security features.

**Feature ID**: FEAT-AUTH-001
**Priority**: High
**Estimated Duration**: 8 weeks
**Total Tasks**: 44

---

## 🎯 Motivation

- **Sorcery gem is unmaintained**: Last update was several years ago, posing security and compatibility risks
- **Rails 8 built-in authentication**: Native support with `has_secure_password` provides a modern, maintained solution
- **Reduce dependencies**: Simplify the dependency tree and improve long-term maintainability
- **Future extensibility**: Implement provider abstraction pattern for future OAuth/MFA support

---

## 📚 Documentation

- **Design Document**: [`docs/designs/rails8-authentication-migration.md`](../docs/designs/rails8-authentication-migration.md) (3,703 lines, iteration 2)
- **Task Plan**: [`docs/plans/rails8-authentication-migration-tasks.md`](../docs/plans/rails8-authentication-migration-tasks.md) (44 tasks, revision 2)
- **Design Evaluations**: `docs/evaluations/design-*-FEAT-AUTH-001.md` (7 evaluators, all approved ≥7.0/10.0)
- **Planning Evaluations**: `docs/evaluations/planner-*-FEAT-AUTH-001.md` (7 evaluators, all approved ≥4.3/5.0)

---

## 🔧 Technical Approach

### Core Changes

1. **Authentication System**
   - Replace Sorcery with `has_secure_password` (bcrypt)
   - Maintain bcrypt compatibility during migration
   - Preserve existing password hashes (30-day rollback window)

2. **Architecture Improvements**
   - **Provider Abstraction**: `Authentication::Provider` interface for future extensibility
   - **Service Layer**: Framework-agnostic `AuthenticationService` for business logic
   - **Reusable Concerns**: Parameterized `BruteForceProtection` and `Authenticatable` concerns

3. **Security Features**
   - Brute force protection: 5 failed attempts → 45-minute account lock
   - Session management with timeout (30 minutes)
   - Secure password requirements (minimum 8 characters)
   - Email notifications for account locks

4. **Observability**
   - Structured logging with Lograge (JSON format)
   - Metrics instrumentation with StatsD
   - Request correlation for distributed tracing
   - Log aggregation strategy (CloudWatch/Papertrail)

5. **Internationalization**
   - Extract hardcoded Japanese messages to I18n
   - Support for Japanese (primary) and English locales

---

## 📦 Implementation Phases

### Phase 1: Database Layer (TASK-001 to TASK-008)
- Add `password_digest` column to `operators` table
- Add brute force protection columns (`failed_logins_count`, `lock_expires_at`, `unlock_token`)
- Add observability columns (`last_login_at`, `last_login_ip`)
- Migrate existing Sorcery password hashes
- **Duration**: 1 week

### Phase 2: Backend Logic (TASK-009 to TASK-023)
- Implement provider abstraction pattern
- Create `AuthenticationService` (framework-agnostic)
- Implement `BruteForceProtection` concern
- Update controllers and helpers
- Extract I18n messages
- **Duration**: 3 weeks

### Phase 3: Observability Setup (TASK-024 to TASK-028)
- Configure Lograge for structured logging
- Implement StatsD metrics
- Set up request correlation
- Create monitoring dashboards
- **Duration**: 1 week

### Phase 4: Frontend Updates (TASK-029 to TASK-033)
- Update login/logout views
- Create account locked page
- Update navigation components
- **Duration**: 1 week

### Phase 5: Testing (TASK-035 to TASK-043)
- Update model specs (≥95% coverage)
- Update controller specs (≥90% coverage)
- Update system tests
- Add security tests
- Add observability tests
- **Duration**: 1.5 weeks

### Phase 6: Deployment (TASK-044 to TASK-048)
- Create rollback plan
- Production deployment with monitoring
- Full regression testing
- Sorcery cleanup
- **Duration**: 0.5 weeks

---

## ✅ Acceptance Criteria

### Functional Requirements
- [ ] FR-1: User login with email/password works identically to Sorcery
- [ ] FR-2: User logout works correctly (session cleanup)
- [ ] FR-3: Password authentication using bcrypt (cost=12 in production)
- [ ] FR-4: All existing operators can log in with current passwords
- [ ] FR-5: Brute force protection (5 attempts → 45-min lock)
- [ ] FR-6: Session timeout after 30 minutes of inactivity
- [ ] FR-7: Authorization (Pundit) continues to work unchanged

### Non-Functional Requirements
- [ ] NFR-1: Zero downtime deployment
- [ ] NFR-2: 30-day rollback capability
- [ ] NFR-3: Test coverage ≥90% (models ≥95%)
- [ ] NFR-4: No breaking changes to existing APIs
- [ ] NFR-5: Security audit passes (Brakeman, bundle-audit)
- [ ] NFR-6: Performance maintained (<500ms p95 latency)

### Observability
- [ ] OBS-1: Structured JSON logs (Lograge)
- [ ] OBS-2: Metrics emission (StatsD)
- [ ] OBS-3: Request correlation IDs in all logs
- [ ] OBS-4: Monitoring dashboards configured
- [ ] OBS-5: Alert rules defined

### Quality Gates
- [ ] All 7 design evaluators approved (≥7.0/10.0) ✅
- [ ] All 7 planning evaluators approved (≥4.3/5.0) ✅
- [ ] All 7 code evaluators approved (≥7.0/10.0)
- [ ] RuboCop passes (0 offenses)
- [ ] RSpec passes (100% green)
- [ ] Brakeman passes (0 warnings)

---

## 🔍 Key Technical Details

### Database Schema Changes

```ruby
# Migration: Add Rails 8 authentication fields
add_column :operators, :password_digest, :string, null: true
add_column :operators, :failed_logins_count, :integer, default: 0, null: false
add_column :operators, :lock_expires_at, :datetime
add_column :operators, :unlock_token, :string
add_column :operators, :last_login_at, :datetime
add_column :operators, :last_login_ip, :string

add_index :operators, :unlock_token, unique: true
```

### Configuration (ENV Variables)

```bash
# Authentication Security
LOGIN_RETRY_LIMIT=5
LOGIN_LOCK_DURATION=2700  # 45 minutes in seconds
PASSWORD_MIN_LENGTH=8
SESSION_TIMEOUT=1800      # 30 minutes in seconds
BCRYPT_COST=12            # Production cost (10 for test)

# Observability
STATSD_HOST=localhost
STATSD_PORT=8125
STATSD_PREFIX=cat_salvages
LOG_LEVEL=info
```

### Provider Abstraction Pattern

```ruby
# Future extensibility without YAGNI violations
module Authentication
  class Provider
    def authenticate(credentials)
      raise NotImplementedError
    end
  end

  class PasswordProvider < Provider
    def authenticate(email:, password:, ip_address:)
      # Password authentication logic
    end
  end

  # Future providers (design only, not implemented):
  # - OAuthProvider
  # - MFAProvider
  # - SamlProvider
end
```

---

## 🚀 Deployment Strategy

1. **Pre-deployment**
   - Run bcrypt compatibility audit
   - Verify all existing passwords are compatible
   - Create database backup

2. **Deployment**
   - Deploy with feature flag disabled
   - Run migration to add new columns
   - Enable feature flag gradually (canary rollout)

3. **Validation**
   - Monitor authentication success rates
   - Check error logs for anomalies
   - Verify session management works

4. **Rollback Plan (30 days)**
   - Keep Sorcery gem installed but disabled
   - Maintain dual password storage
   - Rollback procedure documented in design doc

---

## 📊 Metrics & Monitoring

### Key Metrics
- `auth.attempts` (counter, tags: provider, result)
- `auth.duration` (timing)
- `auth.failures` (counter, tags: reason)
- `auth.account_locked` (counter)

### Dashboards
- Authentication success/failure rates
- Account lock frequency
- Login latency (p50, p95, p99)
- Brute force attack detection

### Alerts
- Login failure rate >10% over 5 minutes
- Account lock rate >5 locks/hour
- Authentication latency >1s p95

---

## 🎓 Reusability Benefits

This implementation provides reusable components for future authentication needs:

1. **Multi-Model Support**: `Authenticatable` concern works with any model (Admin, Customer, etc.)
2. **Framework-Agnostic Service**: `AuthenticationService` usable in Web, CLI, GraphQL, background jobs
3. **Parameterized Concerns**: `BruteForceProtection` configurable per model
4. **I18n Extraction**: Multi-language support ready
5. **Provider Pattern**: Easy to add OAuth, SAML, MFA in future

---

## 🔗 Related Issues

- None (initial implementation)

---

## 👥 Assignees

- Backend: TBD
- Frontend: TBD
- Testing: TBD
- DevOps: TBD

---

## 🏷️ Labels

`feature`, `authentication`, `rails-8`, `high-priority`, `design-approved`, `plan-approved`

---

## 📝 Notes

- **EDAF v1.0 Workflow**: This issue was created following the EDAF 4-phase gate system
  - Phase 1: Design Gate ✅ (All 7 evaluators approved)
  - Phase 2: Planning Gate ✅ (All 7 evaluators approved)
  - Phase 3: Code Review Gate (pending implementation)
  - Phase 4: Deployment Gate (pending deployment)

- **YAGNI Principle**: MFA and OAuth implementations are designed but not implemented. Only password authentication is in scope for this migration.

- **Backward Compatibility**: Existing Sorcery-based passwords will work immediately after migration (bcrypt compatibility).

---

**Created**: 2025-11-24
**Last Updated**: 2025-11-24
**Design Iteration**: 2
**Plan Revision**: 2
