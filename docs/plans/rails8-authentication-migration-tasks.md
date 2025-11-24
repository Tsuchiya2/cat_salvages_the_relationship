# Task Plan - Rails 8 Authentication Migration

**Feature ID**: FEAT-AUTH-001
**Design Document**: docs/designs/rails8-authentication-migration.md
**Created**: 2025-11-24
**Planner**: planner agent

---

## Metadata

```yaml
task_plan_metadata:
  feature_id: "FEAT-AUTH-001"
  feature_name: "Rails 8 Authentication Migration"
  total_tasks: 44
  estimated_duration: "8 weeks"
  critical_path: ["TASK-001", "TASK-002", "TASK-003", "TASK-009", "TASK-010", "TASK-011", "TASK-012", "TASK-013", "TASK-016", "TASK-015", "TASK-020", "TASK-038", "TASK-046", "TASK-047", "TASK-048"]
  worker_breakdown:
    database: 6
    backend: 19
    frontend: 5
    test: 14
  revision: 2
  revision_reason: "Removed YAGNI tasks (TASK-004 MFA migration, TASK-005 OAuth migration, TASK-027 Prometheus, TASK-034 MFA UI), removed MFA detection from TASK-012, added I18n dependencies to frontend tasks (TASK-029, 032, 033)"
```

---

## 1. Overview

**Feature Summary**: Migrate from unmaintained Sorcery gem to Rails 8's built-in authentication system while preserving existing user data, brute force protection, and authorization layer. Includes provider abstraction for future OAuth/MFA support (design only), observability setup, and reusability patterns.

**Total Tasks**: 44 (revised from 48 - removed YAGNI tasks)
**Execution Phases**: 6 (Database → Backend → Observability → Frontend → Testing → Deployment)
**Parallel Opportunities**: 35 out of 44 tasks can be parallelized (80%)

**Key Innovations**:
- Authentication provider abstraction for future extensibility
- Framework-agnostic AuthenticationService layer
- Parameterized concerns for multi-model reuse
- Comprehensive observability with Lograge and StatsD
- I18n extraction for multi-language support

---

## 2. Task Breakdown

### Phase 1: Database Layer (TASK-001 to TASK-008)

#### TASK-001: Create Password Digest Migration
**Description**: Create migration to add `password_digest` column to operators table for Rails 8 authentication

**Dependencies**: None

**Deliverables**:
- File: `db/migrate/YYYYMMDDHHMMSS_add_password_digest_to_operators.rb`
- Migration adds `password_digest` column (string, nullable)
- Migration adds index on `password_digest` for future queries
- Migration includes reversible `up` and `down` methods

**Implementation**:
```ruby
class AddPasswordDigestToOperators < ActiveRecord::Migration[8.1]
  def change
    add_column :operators, :password_digest, :string
    add_index :operators, :password_digest
  end
end
```

**Definition of Done**:
- Migration file created
- Migration runs without errors on development database
- Rollback works correctly
- Schema.rb updated with new column

**Estimated Complexity**: Low
**Assigned To**: database-worker-v1-self-adapting

---

#### TASK-002: Research Sorcery Password Hash Compatibility
**Description**: Investigate whether Sorcery's `crypted_password` format is compatible with Rails 8's `password_digest` for direct migration

**Dependencies**: [TASK-001]

**Deliverables**:
- Technical report: `docs/research/sorcery-bcrypt-compatibility.md`
- Test script to verify password hash compatibility
- Decision on migration strategy (direct copy vs. rehashing)
- Sample test with known operator credentials

**Testing Steps**:
1. Create test operator with Sorcery: `password = 'testpass123'`
2. Export `crypted_password` and `salt` values
3. Manually set `password_digest = crypted_password`
4. Test authentication with `operator.authenticate('testpass123')`
5. Document results and recommendation

**Definition of Done**:
- Compatibility report written
- Test script proves migration strategy works
- Decision documented for team review

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-003: Create Password Hash Migration Script
**Description**: Create data migration to copy password hashes from Sorcery format to Rails 8 format

**Dependencies**: [TASK-002]

**Deliverables**:
- File: `db/migrate/YYYYMMDDHHMMSS_migrate_sorcery_passwords.rb`
- Migration with transaction safety
- Pre-migration validation (check all operators have crypted_password)
- Post-migration validation (check all operators have password_digest)
- Checksums for data integrity verification

**Implementation**:
```ruby
class MigrateSorceryPasswords < ActiveRecord::Migration[8.1]
  def up
    # Pre-migration validation
    missing_password = Operator.where(crypted_password: nil).count
    raise "#{missing_password} operators missing crypted_password" if missing_password > 0

    Operator.find_each do |operator|
      operator.update_column(:password_digest, operator.crypted_password)
    end

    # Post-migration validation
    missing_digest = Operator.where(password_digest: nil).count
    raise "Migration failed: #{missing_digest} missing password_digest" if missing_digest > 0
  end

  def down
    Operator.update_all(password_digest: nil)
  end
end
```

**Definition of Done**:
- Migration runs successfully on test database
- All operators have password_digest populated
- Validation checks pass
- Test operator can authenticate with known password

**Estimated Complexity**: Medium
**Assigned To**: database-worker-v1-self-adapting

---

<!--
TASK-004 and TASK-005 REMOVED (Revision 2)
Reason: YAGNI violation - MFA and OAuth are not part of current requirements
These features are documented in design for future reference but should not be implemented now
Implement when actual requirements are confirmed
-->

---

#### TASK-006: Create Data Migration Validator Utility
**Description**: Create reusable utility class for validating data migrations with checksums and integrity checks

**Dependencies**: None

**Deliverables**:
- File: `app/services/data_migration_validator.rb`
- Methods: `generate_checksum(records)`, `validate_migration(before, after)`, `verify_integrity(model)`
- Usage example in migration scripts
- RSpec tests for validator

**Implementation**:
```ruby
class DataMigrationValidator
  def self.generate_checksum(model_class)
    records = model_class.pluck(:id, :email, :crypted_password, :password_digest)
    records.map { |r| Digest::SHA256.hexdigest(r.join(':')) }
  end

  def self.validate_password_migration
    missing = Operator.where(password_digest: nil).where.not(crypted_password: nil).count
    raise "Migration incomplete: #{missing} operators missing password_digest" if missing > 0
    true
  end
end
```

**Definition of Done**:
- Validator class implemented
- All methods tested with RSpec
- Used in password migration script
- Documentation included

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-007: Create Remove Sorcery Columns Migration (Post-Verification)
**Description**: Create migration to remove Sorcery-specific columns after successful production verification

**Dependencies**: [TASK-003]

**Deliverables**:
- File: `db/migrate/YYYYMMDDHHMMSS_remove_sorcery_columns_from_operators.rb`
- Removes: `crypted_password`, `salt` columns
- Reversible migration with rollback support
- WARNING comments about timing (run only after 30-day verification period)

**Implementation**:
```ruby
class RemoveSorceryColumnsFromOperators < ActiveRecord::Migration[8.1]
  def up
    # WARNING: Only run after 30-day production verification period
    # Ensure all operators can authenticate with password_digest
    remove_column :operators, :crypted_password
    remove_column :operators, :salt
  end

  def down
    add_column :operators, :crypted_password, :string
    add_column :operators, :salt, :string
  end
end
```

**Definition of Done**:
- Migration file created with clear warnings
- Reversible migration tested
- **NOT RUN** until Phase 6 cleanup

**Estimated Complexity**: Low
**Assigned To**: database-worker-v1-self-adapting

---

#### TASK-008: Create Email Validator Utility
**Description**: Create reusable email validation and normalization utility class

**Dependencies**: None

**Deliverables**:
- File: `app/validators/email_validator.rb`
- Methods: `valid_format?(email)`, `normalize(email)`, `sanitize(email)`
- Support for custom email regex patterns
- RSpec tests for validator

**Implementation**:
```ruby
module Validators
  class EmailValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      return if value.blank?

      unless value.match?(/\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/)
        record.errors.add(attribute, :invalid)
      end
    end

    def self.normalize(email)
      email.to_s.downcase.strip
    end
  end
end
```

**Definition of Done**:
- EmailValidator class implemented
- Validates email format per design spec
- Normalizes email to lowercase
- RSpec tests cover edge cases

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

### Phase 2: Backend - Core Authentication (TASK-009 to TASK-023)

#### TASK-009: Implement AuthResult Value Object
**Description**: Create AuthResult value object to represent authentication outcomes (success, failed, pending_mfa)

**Dependencies**: None

**Deliverables**:
- File: `app/services/auth_result.rb`
- Attributes: `status`, `user`, `reason`
- Class methods: `success(user:)`, `failed(reason, user:)`, `pending_mfa(user:)`
- Instance methods: `success?`, `failed?`, `pending_mfa?`
- RSpec tests

**Implementation**:
```ruby
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

**Definition of Done**:
- AuthResult class implemented
- All factory methods tested
- Predicate methods tested
- Immutability verified

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-010: Implement Authentication::Provider Base Class
**Description**: Create abstract base class for authentication providers (password, OAuth, SAML, MFA)

**Dependencies**: [TASK-009]

**Deliverables**:
- File: `app/services/authentication/provider.rb`
- Abstract methods: `authenticate(credentials)`, `supports?(credential_type)`
- Raises NotImplementedError if not overridden
- Documentation for extending providers

**Implementation**:
```ruby
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
```

**Definition of Done**:
- Provider base class created
- NotImplementedError raised for abstract methods
- Documentation written for subclass implementation

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-011: Implement Authentication::PasswordProvider
**Description**: Create password authentication provider using Rails 8's has_secure_password

**Dependencies**: [TASK-010]

**Deliverables**:
- File: `app/services/authentication/password_provider.rb`
- Inherits from `Authentication::Provider`
- Method: `authenticate(email:, password:)` returns `AuthResult`
- Integrates with BruteForceProtection concern
- Checks account lock status before authentication
- RSpec tests with mocked operators

**Implementation**:
```ruby
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
```

**Definition of Done**:
- PasswordProvider implemented
- Returns AuthResult for all scenarios
- Brute force protection integrated
- RSpec tests cover success, failure, locked account

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-012: Implement AuthenticationService (Framework-Agnostic)
**Description**: Create framework-agnostic authentication service layer that coordinates providers

**Dependencies**: [TASK-011]

**Deliverables**:
- File: `app/services/authentication_service.rb`
- Method: `authenticate(provider_type, ip_address:, **credentials)` returns `AuthResult`
- Provider routing logic (password only for now; oauth/saml for future)
- Request correlation logging
- RSpec tests with stubbed providers

**Implementation**:
```ruby
class AuthenticationService
  class << self
    def authenticate(provider_type, ip_address: nil, **credentials)
      provider = provider_for(provider_type)
      result = provider.authenticate(**credentials)

      log_authentication_attempt(provider_type, result, ip_address)
      result
    end

    private

    def provider_for(type)
      case type
      when :password
        Authentication::PasswordProvider.new
      # Future: OAuth and SAML providers
      # when :oauth
      #   Authentication::OAuthProvider.new
      # when :saml
      #   Authentication::SamlProvider.new
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
```

**Definition of Done**:
- AuthenticationService implemented
- Provider routing works correctly (password provider only)
- Logging includes request correlation
- RSpec tests cover password provider

**Estimated Complexity**: High
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-013: Implement BruteForceProtection Concern (Parameterized)
**Description**: Create parameterized concern for brute force protection that can be reused across models

**Dependencies**: None

**Deliverables**:
- File: `app/models/concerns/brute_force_protection.rb`
- Configurable attributes: `lock_retry_limit`, `lock_duration`, `lock_notifier`
- Methods: `increment_failed_logins!`, `reset_failed_logins!`, `lock_account!`, `unlock_account!`, `locked?`
- Uses ENV-based configuration from `Rails.configuration.authentication`
- RSpec tests for concern behavior

**Implementation**:
```ruby
module BruteForceProtection
  extend ActiveSupport::Concern

  included do
    class_attribute :lock_retry_limit, default: -> { Rails.configuration.authentication[:login_retry_limit] }
    class_attribute :lock_duration, default: -> { Rails.configuration.authentication[:login_lock_duration] }
    class_attribute :lock_notifier
  end

  def increment_failed_logins!
    increment!(:failed_logins_count)
    lock_account! if failed_logins_count >= lock_retry_limit
  end

  def reset_failed_logins!
    update(failed_logins_count: 0, lock_expires_at: nil)
  end

  def lock_account!
    update(
      lock_expires_at: Time.current + lock_duration,
      unlock_token: SecureRandom.urlsafe_base64(32)
    )
  end

  def unlock_account!
    update(lock_expires_at: nil, unlock_token: nil, failed_logins_count: 0)
  end

  def locked?
    lock_expires_at.present? && lock_expires_at > Time.current
  end

  def mail_notice(ip_address)
    lock_notifier&.call(self, ip_address)
  end
end
```

**Definition of Done**:
- Concern implemented with parameterized configuration
- All methods tested
- ENV-based configuration integrated
- Works with multiple models

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-014: Implement Authenticatable Concern (Multi-Model)
**Description**: Create generic authenticatable concern that can be reused for Operator, Admin, Customer models

**Dependencies**: None

**Deliverables**:
- File: `app/models/concerns/authenticatable.rb`
- Class method: `authenticates_with(model:, path_prefix:)`
- Instance methods for authentication helpers
- RSpec tests showing multi-model usage

**Implementation**:
```ruby
module Authenticatable
  extend ActiveSupport::Concern

  class_methods do
    def authenticates_with(model:, path_prefix: nil)
      @authenticated_model = model
      @path_prefix = path_prefix
    end

    attr_reader :authenticated_model, :path_prefix
  end
end
```

**Definition of Done**:
- Authenticatable concern implemented
- Supports model configuration
- RSpec tests with Operator and hypothetical Admin models

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-015: Implement Authentication Concern for Controllers
**Description**: Create Authentication concern for controllers providing login, logout, current_operator helpers

**Dependencies**: [TASK-012]

**Deliverables**:
- File: `app/controllers/concerns/authentication.rb`
- Methods: `authenticate_operator(email, password)`, `login(operator)`, `logout`, `current_operator`, `operator_signed_in?`, `require_authentication`
- Helper methods exposed to views
- Session fixation protection (reset_session on login)
- RSpec tests for controller concern

**Implementation**:
```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_operator
    helper_method :current_operator
    helper_method :operator_signed_in?
  end

  def authenticate_operator(email, password)
    result = AuthenticationService.authenticate(:password, email: email, password: password, ip_address: request.remote_ip)

    if result.success?
      result.user
    elsif result.failed? && result.reason == :account_locked
      result.user.mail_notice(request.remote_ip)
      nil
    else
      nil
    end
  end

  def login(operator)
    reset_session # Prevent session fixation
    session[:operator_id] = operator.id
    @current_operator = operator
  end

  def logout
    reset_session
    @current_operator = nil
  end

  def current_operator
    @current_operator
  end

  def operator_signed_in?
    current_operator.present?
  end

  def require_authentication
    unless operator_signed_in?
      not_authenticated
    end
  end

  def not_authenticated
    redirect_to operator_cat_in_path, alert: t('authentication.errors.session_expired')
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

**Definition of Done**:
- Authentication concern implemented
- All methods tested
- Session fixation protection verified
- Helper methods work in views

**Estimated Complexity**: High
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-016: Update Operator Model with has_secure_password
**Description**: Update Operator model to use Rails 8's has_secure_password and integrate concerns

**Dependencies**: [TASK-013]

**Deliverables**:
- File: `app/models/operator.rb` (updated)
- Add `has_secure_password` macro
- Include `BruteForceProtection` concern
- Configure brute force settings (retry_limit: 5, duration: 45.minutes)
- Configure lock notifier: `SessionMailer.notice`
- Update validations (password optional for OAuth users)
- Before validation callback: `normalize_email`

**Implementation**:
```ruby
class Operator < ApplicationRecord
  # Rails 8 authentication
  has_secure_password

  # Concerns
  include BruteForceProtection

  # Brute Force Configuration
  self.lock_retry_limit = 5
  self.lock_duration = 45.minutes
  self.lock_notifier = ->(operator, ip) { SessionMailer.notice(operator, ip).deliver_later }

  # Enums
  enum :role, { operator: 0, guest: 1 }

  # Validations
  validates :name, presence: true, length: { in: 2..255 }
  validates :email, presence: true, uniqueness: true
  validates :email, email: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }, allow_nil: true
  validates :role, presence: true

  # Callbacks
  before_validation :normalize_email

  private

  def normalize_email
    self.email = Validators::EmailValidator.normalize(email) if email.present?
  end
end
```

**Definition of Done**:
- `has_secure_password` added
- BruteForceProtection concern included
- Brute force settings configured
- Validations updated
- Email normalization works
- RSpec model tests pass

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-017: Implement SessionManager Utility
**Description**: Create reusable session lifecycle management utility for multiple user types

**Dependencies**: None

**Deliverables**:
- File: `app/services/session_manager.rb`
- Methods: `create_session(user, session_hash)`, `destroy_session(session_hash)`, `validate_session(session_hash)`, `session_timeout_at(created_at)`
- Support for configurable timeouts
- RSpec tests

**Implementation**:
```ruby
class SessionManager
  class << self
    def create_session(user, session_hash)
      session_hash.delete(:_csrf_token) # Reset CSRF token
      session_hash[:user_id] = user.id
      session_hash[:user_type] = user.class.name
      session_hash[:created_at] = Time.current
      session_hash[:last_activity_at] = Time.current
    end

    def destroy_session(session_hash)
      session_hash.clear
    end

    def validate_session(session_hash)
      return false unless session_hash[:user_id].present?

      created_at = session_hash[:created_at]
      last_activity = session_hash[:last_activity_at]

      return false if session_expired?(created_at, last_activity)

      session_hash[:last_activity_at] = Time.current
      true
    end

    private

    def session_expired?(created_at, last_activity)
      absolute_timeout = Rails.configuration.authentication[:session_absolute_timeout]
      idle_timeout = Rails.configuration.authentication[:session_timeout]

      (Time.current - created_at > absolute_timeout) ||
      (Time.current - last_activity > idle_timeout)
    end
  end
end
```

**Definition of Done**:
- SessionManager implemented
- Session validation with timeouts
- RSpec tests for all scenarios

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-018: Implement PasswordMigrator Utility
**Description**: Create reusable password migration utility for migrating between authentication systems

**Dependencies**: [TASK-002]

**Deliverables**:
- File: `app/services/password_migrator.rb`
- Methods: `migrate_from_sorcery(operator)`, `validate_migration(operator, test_password)`, `batch_migrate(operators)`
- Transaction safety
- RSpec tests

**Implementation**:
```ruby
class PasswordMigrator
  class << self
    def migrate_from_sorcery(operator)
      return false if operator.crypted_password.blank?

      operator.update_column(:password_digest, operator.crypted_password)
      true
    end

    def validate_migration(operator, test_password)
      operator.authenticate(test_password).present?
    end

    def batch_migrate(operators)
      migrated = 0
      failed = []

      operators.find_each do |operator|
        if migrate_from_sorcery(operator)
          migrated += 1
        else
          failed << operator.id
        end
      end

      { migrated: migrated, failed: failed }
    end
  end
end
```

**Definition of Done**:
- PasswordMigrator implemented
- Batch migration with reporting
- RSpec tests with Sorcery-formatted passwords

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-019: Create Authentication Configuration Initializer
**Description**: Create initializer for authentication configuration using ENV variables

**Dependencies**: None

**Deliverables**:
- File: `config/initializers/authentication_config.rb`
- ENV variables for: `LOGIN_RETRY_LIMIT`, `LOGIN_LOCK_DURATION`, `PASSWORD_MIN_LENGTH`, `SESSION_TIMEOUT`, `BCRYPT_COST`, `AUTH_OAUTH_ENABLED`, `AUTH_MFA_ENABLED`
- Default values for all environments
- Documentation comments for each setting

**Implementation**:
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

  # OAuth Providers
  oauth_providers: ENV.fetch('OAUTH_PROVIDERS', '').split(',').map(&:strip),
  google_client_id: ENV['GOOGLE_OAUTH_CLIENT_ID'],
  google_client_secret: ENV['GOOGLE_OAUTH_CLIENT_SECRET'],
}
```

**Definition of Done**:
- Initializer created with all ENV variables
- Defaults work for all environments
- Documentation comments added
- Tested by loading Rails environment

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-020: Update Operator Sessions Controller
**Description**: Update OperatorSessionsController to use new Authentication concern

**Dependencies**: [TASK-015]

**Deliverables**:
- File: `app/controllers/operator/operator_sessions_controller.rb` (updated)
- Use `authenticate_operator(email, password)` instead of Sorcery's `login`
- Use `login(operator)` for session creation
- Use `logout` for session destruction
- Update flash messages to use I18n keys
- Handle AuthResult scenarios

**Implementation**:
```ruby
class Operator::OperatorSessionsController < Operator::BaseController
  skip_before_action :require_authentication, only: [:new, :create]

  def new
  end

  def create
    operator = authenticate_operator(params[:email], params[:password])

    if operator
      login(operator)
      redirect_to operator_operates_path, notice: t('operator.sessions.login_success')
    else
      flash.now[:alert] = t('operator.sessions.login_failure')
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: t('operator.sessions.logout_success')
  end
end
```

**Definition of Done**:
- Controller updated to use Authentication concern
- Sorcery methods removed
- I18n keys used for flash messages
- RSpec controller tests pass

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-021: Update Operator Base Controller
**Description**: Update Operator::BaseController to use new Authentication concern

**Dependencies**: [TASK-015]

**Deliverables**:
- File: `app/controllers/operator/base_controller.rb` (updated)
- Replace Sorcery's `require_login` with `require_authentication`
- Update `not_authenticated` method
- Update `pundit_user` to use `current_operator`

**Implementation**:
```ruby
class Operator::BaseController < ApplicationController
  before_action :require_authentication

  private

  def not_authenticated
    redirect_to root_path
  end

  def pundit_user
    current_operator
  end
end
```

**Definition of Done**:
- BaseController updated
- `require_authentication` replaces `require_login`
- Pundit integration works
- RSpec tests pass for protected actions

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-022: Update Application Controller
**Description**: Update ApplicationController to include Authentication concern

**Dependencies**: [TASK-015]

**Deliverables**:
- File: `app/controllers/application_controller.rb` (updated)
- Include `Authentication` concern
- Remove Sorcery-related includes
- Retain Pundit authorization

**Implementation**:
```ruby
class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Existing Pundit configuration remains
end
```

**Definition of Done**:
- ApplicationController includes Authentication
- Sorcery removed
- Pundit still works
- RSpec tests pass

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-023: Create I18n Locale Files for Authentication
**Description**: Extract all authentication-related messages to I18n locale files (Japanese and English)

**Dependencies**: None

**Deliverables**:
- File: `config/locales/authentication.ja.yml`
- File: `config/locales/authentication.en.yml`
- Translation keys for: login success/failure, logout, account locked, invalid credentials, session expired, MFA messages
- Preserve custom cat emoji messages ("🐾 キャットイン 🐾")

**Implementation**:
```yaml
# config/locales/authentication.ja.yml
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
      session_expired: "セッションが切れました。再度ログインしてください。"
      mfa_required: "多要素認証コードを入力してください"
      mfa_invalid: "認証コードが正しくありません"

# config/locales/authentication.en.yml
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
      session_expired: "Session expired. Please log in again."
      mfa_required: "Please enter your MFA code"
      mfa_invalid: "Invalid MFA code"
```

**Definition of Done**:
- Locale files created for both languages
- All authentication messages extracted
- Cat emoji messages preserved
- Controllers use I18n keys

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

### Phase 3: Observability Setup (TASK-024 to TASK-028)

#### TASK-024: Configure Lograge for Structured Logging
**Description**: Configure Lograge gem for JSON-structured authentication logs

**Dependencies**: None

**Deliverables**:
- File: `config/initializers/lograge.rb`
- Gem: `lograge` added to Gemfile
- JSON formatter configured
- Custom fields: `request_id`, `event`, `email`, `ip`, `user_agent`, `result`, `reason`
- Event types: `authentication_attempt`, `account_locked`, `session_created`, `session_destroyed`

**Implementation**:
```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      ip: event.payload[:ip],
      user_agent: event.payload[:user_agent],
      event_type: event.payload[:event_type],
      user_id: event.payload[:user_id],
      user_email: event.payload[:user_email],
      result: event.payload[:result],
      reason: event.payload[:reason],
      timestamp: Time.current.iso8601
    }
  end
end
```

**Definition of Done**:
- Lograge configured
- JSON-formatted logs output
- Custom fields included in logs
- Tested with sample authentication attempt

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-025: Configure StatsD for Metrics Instrumentation
**Description**: Configure StatsD client for real-time authentication metrics

**Dependencies**: None

**Deliverables**:
- Gem: `statsd-instrument` added to Gemfile
- File: `config/initializers/statsd.rb`
- Metrics: `auth.attempts`, `auth.success`, `auth.failures`, `auth.duration`, `auth.locked_accounts`
- Tags: `provider`, `result`, `reason`
- Integration with AuthenticationService

**Implementation**:
```ruby
# config/initializers/statsd.rb
require 'statsd-instrument'

StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new(
  ENV.fetch('STATSD_HOST', 'localhost'),
  ENV.fetch('STATSD_PORT', '8125').to_i
)

StatsD.prefix = 'cat_salvages'
StatsD.default_sample_rate = ENV.fetch('STATSD_SAMPLE_RATE', '1.0').to_f

# app/services/authentication_service.rb (updated)
def authenticate(provider_type, ip_address: nil, **credentials)
  start_time = Time.current

  provider = provider_for(provider_type)
  result = provider.authenticate(**credentials)

  # Record metrics
  StatsD.increment('auth.attempts', tags: ["provider:#{provider_type}"])
  StatsD.increment("auth.#{result.status}", tags: ["provider:#{provider_type}", "reason:#{result.reason}"])
  StatsD.measure('auth.duration', (Time.current - start_time) * 1000, tags: ["provider:#{provider_type}"])

  result
end
```

**Definition of Done**:
- StatsD configured
- Metrics instrumented in AuthenticationService
- Tags provide dimensionality
- Tested with local StatsD server

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-026: Implement Request Correlation Middleware
**Description**: Create middleware to inject request_id into all authentication flows and logs

**Dependencies**: None

**Deliverables**:
- File: `app/middleware/request_correlation.rb`
- Gem: `request_store` added to Gemfile
- Inject `request_id` from `X-Request-ID` header or generate UUID
- Store in `RequestStore.store[:request_id]`
- Propagate to logs, background jobs, emails

**Implementation**:
```ruby
# app/middleware/request_correlation.rb
class RequestCorrelation
  def initialize(app)
    @app = app
  end

  def call(env)
    request_id = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid
    RequestStore.store[:request_id] = request_id

    @app.call(env)
  ensure
    RequestStore.clear!
  end
end

# config/application.rb (add middleware)
config.middleware.insert_before Rails::Rack::Logger, RequestCorrelation
```

**Definition of Done**:
- Middleware implemented
- Request ID injected or generated
- RequestStore propagates request_id
- Logs include request_id

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

<!--
TASK-027 REMOVED (Revision 2)
Reason: Infrastructure not defined - Prometheus requires infrastructure setup that's outside scope
Implement when Prometheus infrastructure is confirmed and deployed
-->

---

#### TASK-028: Document Observability Setup
**Description**: Create documentation for observability setup (Lograge, StatsD, log aggregation)

**Dependencies**: [TASK-024, TASK-025, TASK-026]

**Deliverables**:
- File: `docs/observability/authentication-monitoring.md`
- Log aggregation strategy (CloudWatch Logs, Papertrail, retention policies)
- Grafana dashboard configuration examples
- Alert rules for authentication failures
- Runbook for investigating authentication issues

**Content Outline**:
- Logging setup (Lograge, JSON format, custom fields)
- Metrics setup (StatsD, tags, dashboard queries)
- Request correlation (request_id propagation)
- Prometheus metrics endpoint
- Grafana dashboard examples
- Alert thresholds (failure rate >5%, lock rate >10%)
- Troubleshooting guide

**Definition of Done**:
- Documentation written
- Dashboard examples provided
- Alert rules defined
- Runbook included

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

### Phase 4: Frontend Updates (TASK-029 to TASK-033)

#### TASK-029: Update Login Form View
**Description**: Update login form view to ensure compatibility with new authentication flow

**Dependencies**: [TASK-020, TASK-023]

**Deliverables**:
- File: `app/views/operator/operator_sessions/new.html.slim` (updated)
- Ensure form parameters match controller expectations
- Update error message display to use I18n
- Verify cat emoji button text preserved

**Implementation**:
```slim
h1 = t('operator.sessions.new_session')

= form_with url: operator_cat_in_path, local: true do |f|
  - if flash[:alert]
    .alert.alert-danger = flash[:alert]

  .form-group
    = f.label :email, t('activerecord.attributes.operator.email')
    = f.email_field :email, class: 'form-control', autofocus: true

  .form-group
    = f.label :password, t('activerecord.attributes.operator.password')
    = f.password_field :password, class: 'form-control'

  .actions
    = f.submit t('operator.sessions.submit_button'), class: 'btn btn-primary'
```

**Definition of Done**:
- Form parameters match controller
- I18n keys used
- Cat emoji preserved
- Error messages display correctly

**Estimated Complexity**: Low
**Assigned To**: frontend-worker-v1-self-adapting

---

#### TASK-030: Update Login Form Routes
**Description**: Verify and update routes for login/logout to match new controller structure

**Dependencies**: [TASK-020]

**Deliverables**:
- File: `config/routes.rb` (verify/update)
- Routes: `operator_cat_in_path` (new session), `operator_cat_in_path` (create session), `operator_cat_out_path` (destroy session)
- Ensure route helpers work in controllers and views

**Current Routes (verify unchanged)**:
```ruby
namespace :operator do
  get 'cat_in', to: 'operator_sessions#new', as: :cat_in
  post 'cat_in', to: 'operator_sessions#create'
  delete 'cat_out', to: 'operator_sessions#destroy', as: :cat_out
end
```

**Definition of Done**:
- Routes verified or updated
- Route helpers work in controllers
- Route helpers work in views

**Estimated Complexity**: Low
**Assigned To**: frontend-worker-v1-self-adapting

---

#### TASK-031: Update Flash Messages Display
**Description**: Ensure flash messages (success, alert, error) display correctly with I18n translations

**Dependencies**: [TASK-023]

**Deliverables**:
- File: `app/views/layouts/application.html.slim` (verify/update)
- Flash message rendering for `:notice`, `:alert`, `:error`
- Bootstrap styling applied
- Test with login success/failure scenarios

**Implementation**:
```slim
- flash.each do |type, message|
  .alert class="alert-#{type == 'notice' ? 'success' : 'danger'}" role="alert"
    = message
```

**Definition of Done**:
- Flash messages display correctly
- Bootstrap styling applied
- Login success shows success message
- Login failure shows error message

**Estimated Complexity**: Low
**Assigned To**: frontend-worker-v1-self-adapting

---

#### TASK-032: Create Account Locked Page
**Description**: Create dedicated page for locked account notification with time remaining

**Dependencies**: [TASK-020, TASK-023]

**Deliverables**:
- File: `app/views/operator/operator_sessions/locked.html.slim` (new)
- Display locked account message with unlock time
- Link to support/contact
- I18n translations

**Implementation**:
```slim
.container
  .row
    .col-md-6.offset-md-3
      .alert.alert-warning
        h2 = t('operator.sessions.account_locked_title')
        p = t('operator.sessions.account_locked_message', time: distance_of_time_in_words_to_now(@operator.lock_expires_at))
        p = t('operator.sessions.account_locked_help')

        = link_to t('operator.sessions.back_to_login'), operator_cat_in_path, class: 'btn btn-primary'
```

**Definition of Done**:
- Locked page created
- Time remaining displayed
- I18n translations used
- Accessible from controller redirect

**Estimated Complexity**: Low
**Assigned To**: frontend-worker-v1-self-adapting

---

#### TASK-033: Update Navigation Logout Link
**Description**: Update navigation bar logout link to use new route helper

**Dependencies**: [TASK-020, TASK-023]

**Deliverables**:
- File: `app/views/layouts/_navigation.html.slim` (or similar)
- Update logout link to use `operator_cat_out_path` with DELETE method
- Verify `current_operator` helper works
- Test logout functionality

**Implementation**:
```slim
- if operator_signed_in?
  li.nav-item
    = link_to t('operator.sessions.logout'), operator_cat_out_path, method: :delete, class: 'nav-link'
```

**Definition of Done**:
- Logout link updated
- DELETE method used
- Helper methods work
- Logout redirects correctly

**Estimated Complexity**: Low
**Assigned To**: frontend-worker-v1-self-adapting

---

<!--
TASK-034 REMOVED (Revision 2)
Reason: YAGNI violation - MFA UI is not part of current requirements
The design document includes MFA for future planning, but actual implementation should only happen when MFA is confirmed as a requirement
Implement when MFA backend support is ready and requirements are confirmed
-->

---

### Phase 5: Testing (TASK-035 to TASK-043)

#### TASK-035: Update Operator Model Specs
**Description**: Update RSpec tests for Operator model to test has_secure_password and BruteForceProtection

**Dependencies**: [TASK-016]

**Deliverables**:
- File: `spec/models/operator_spec.rb` (updated)
- Tests for: password validation, password confirmation, email normalization, brute force protection, account locking, unlock functionality
- Remove Sorcery-specific tests
- Coverage ≥95%

**Test Cases**:
- Password minimum length (8 characters)
- Password confirmation required
- Email uniqueness
- Email normalization to lowercase
- Failed login increment
- Account lock after 5 failed attempts
- Automatic unlock after 45 minutes
- Manual unlock

**Definition of Done**:
- All model specs pass
- Sorcery tests removed
- Code coverage ≥95%

**Estimated Complexity**: Medium
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-036: Create Authentication Service Specs
**Description**: Create comprehensive RSpec tests for AuthenticationService

**Dependencies**: [TASK-012]

**Deliverables**:
- File: `spec/services/authentication_service_spec.rb` (new)
- Tests for: password authentication, provider routing, MFA detection, logging
- Mock AuthResult objects
- Coverage ≥95%

**Test Cases**:
- Successful password authentication
- Failed authentication (wrong password)
- Account locked authentication attempt
- MFA-enabled user returns pending_mfa
- Unknown provider raises ArgumentError
- Logs authentication attempts

**Definition of Done**:
- All service specs pass
- Providers mocked correctly
- Code coverage ≥95%

**Estimated Complexity**: High
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-037: Create BruteForceProtection Concern Specs
**Description**: Create RSpec tests for BruteForceProtection concern

**Dependencies**: [TASK-013]

**Deliverables**:
- File: `spec/models/concerns/brute_force_protection_spec.rb` (new)
- Tests for: increment_failed_logins!, reset_failed_logins!, lock_account!, unlock_account!, locked?, mail_notice
- Test with shared example for reusability
- Coverage ≥95%

**Test Cases**:
- Increment failed logins count
- Lock account after retry limit reached
- Reset failed logins on successful authentication
- Check locked status based on expiry time
- Unlock account manually
- Send email notification on lock

**Definition of Done**:
- All concern specs pass
- Shared examples created
- Code coverage ≥95%

**Estimated Complexity**: Medium
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-038: Update Operator Sessions Controller Specs
**Description**: Update RSpec controller tests for OperatorSessionsController

**Dependencies**: [TASK-020]

**Deliverables**:
- File: `spec/controllers/operator/operator_sessions_controller_spec.rb` (updated)
- Tests for: login success, login failure, logout, account locked scenario
- Remove Sorcery-specific tests
- Mock AuthenticationService
- Coverage ≥95%

**Test Cases**:
- POST create with valid credentials creates session
- POST create with invalid credentials renders error
- POST create with locked account shows error and sends email
- DELETE destroy logs out operator
- Redirect after login
- Flash messages displayed correctly

**Definition of Done**:
- All controller specs pass
- AuthenticationService mocked
- Flash messages tested
- Code coverage ≥95%

**Estimated Complexity**: High
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-039: Update System Specs for Authentication
**Description**: Update RSpec system tests for full authentication flow

**Dependencies**: [TASK-029, TASK-033]

**Deliverables**:
- File: `spec/system/operator_sessions_spec.rb` (updated)
- Tests for: login success, login failure, account lock, logout
- Update login helper macro
- Remove Sorcery dependencies
- Use Rails 8 authentication

**Test Cases**:
- Operator can log in with valid credentials
- Operator cannot log in with invalid credentials
- Account locks after 5 failed attempts
- Locked account shows error message
- Operator can log out successfully
- Session persists across requests

**Definition of Done**:
- All system specs pass
- Login helper updated
- Sorcery removed from tests
- Tests pass in headless browser

**Estimated Complexity**: High
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-040: Create Password Migration Specs
**Description**: Create RSpec tests for password migration from Sorcery to Rails 8

**Dependencies**: [TASK-003, TASK-018]

**Deliverables**:
- File: `spec/services/password_migrator_spec.rb` (new)
- Tests for: single operator migration, batch migration, validation
- Mock Sorcery password format
- Coverage ≥95%

**Test Cases**:
- Migrate single operator successfully
- Batch migrate all operators
- Validate migrated password works
- Handle missing crypted_password
- Report migration failures

**Definition of Done**:
- All migration specs pass
- Sorcery format mocked
- Code coverage ≥95%

**Estimated Complexity**: Medium
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-041: Create Observability Specs
**Description**: Create RSpec tests for observability setup (Lograge, StatsD, request correlation)

**Dependencies**: [TASK-024, TASK-025, TASK-026]

**Deliverables**:
- File: `spec/middleware/request_correlation_spec.rb` (new)
- File: `spec/services/authentication_service_spec.rb` (add observability tests)
- Tests for: request_id injection, log formatting, metrics recording
- Coverage ≥90%

**Test Cases**:
- Request ID generated if not present
- Request ID extracted from header
- Logs include request_id
- StatsD metrics recorded on authentication
- Metrics include correct tags

**Definition of Done**:
- All observability specs pass
- Logs verified
- Metrics verified
- Code coverage ≥90%

**Estimated Complexity**: Medium
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-042: Create Security Test Suite
**Description**: Create security-focused test suite for authentication (Brakeman, penetration tests)

**Dependencies**: [TASK-038]

**Deliverables**:
- File: `spec/security/authentication_security_spec.rb` (new)
- Tests for: session fixation prevention, CSRF protection, timing attacks, password hashing strength
- Brakeman security scan configuration
- Coverage of all threat scenarios from design

**Test Cases**:
- Session reset on login prevents fixation
- CSRF token validated on login/logout
- Password comparison is constant-time
- Bcrypt cost factor is ≥12 in production
- Password not logged in Rails logs
- Account lock prevents brute force

**Definition of Done**:
- All security specs pass
- Brakeman scan passes with no critical issues
- Security checklist complete

**Estimated Complexity**: High
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-043: Update Factory Bot Factories
**Description**: Update FactoryBot operator factory to use has_secure_password

**Dependencies**: [TASK-016]

**Deliverables**:
- File: `spec/factories/operators.rb` (updated)
- Factory uses `password` attribute instead of `crypted_password`
- Default password: 'password'
- Factory traits for: locked account, with MFA, with OAuth

**Implementation**:
```ruby
FactoryBot.define do
  factory :operator do
    name { 'Test Operator' }
    sequence(:email) { |n| "operator#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
    role { :operator }

    trait :locked do
      failed_logins_count { 5 }
      lock_expires_at { 30.minutes.from_now }
      unlock_token { SecureRandom.urlsafe_base64(32) }
    end

    trait :with_mfa do
      mfa_enabled { true }
      mfa_secret { 'test_mfa_secret' }
      mfa_method { 'totp' }
    end

    trait :with_oauth do
      oauth_provider { 'google' }
      oauth_uid { SecureRandom.uuid }
      password { nil }
      password_confirmation { nil }
    end
  end
end
```

**Definition of Done**:
- Factory updated to use password
- Traits created for testing scenarios
- All tests using factory pass

**Estimated Complexity**: Low
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-044: Update Login Helper Macros
**Description**: Update RSpec support login helper macros to use new authentication

**Dependencies**: [TASK-043]

**Deliverables**:
- File: `spec/support/login_macros.rb` (updated)
- Helper: `login(operator)` for system tests
- Uses new session creation mechanism
- Remove Sorcery dependencies

**Implementation**:
```ruby
module LoginMacros
  def login(operator)
    visit operator_cat_in_path
    fill_in 'Email', with: operator.email
    fill_in 'Password', with: 'password'
    click_button I18n.t('operator.sessions.submit_button')
  end

  def logout
    click_link I18n.t('operator.sessions.logout')
  end
end

RSpec.configure do |config|
  config.include LoginMacros, type: :system
end
```

**Definition of Done**:
- Login helper updated
- Sorcery removed
- All system tests using helper pass

**Estimated Complexity**: Low
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-045: Create Performance Benchmark Tests
**Description**: Create performance benchmark tests for authentication (login latency <500ms p95)

**Dependencies**: [TASK-038]

**Deliverables**:
- File: `spec/performance/authentication_benchmark_spec.rb` (new)
- Benchmark: Login request duration
- Target: p95 <500ms
- Gem: `benchmark-ips` or `rspec-benchmark`
- Report with percentiles (p50, p95, p99)

**Test Cases**:
- Measure successful login duration
- Measure failed login duration
- Measure locked account check duration
- Report latency percentiles

**Definition of Done**:
- Benchmark tests created
- p95 latency <500ms achieved
- Report generated

**Estimated Complexity**: Medium
**Assigned To**: test-worker-v1-self-adapting

---

#### TASK-046: Run Full Test Suite and Fix Failures
**Description**: Run complete RSpec test suite and fix any failures

**Dependencies**: [TASK-035, TASK-036, TASK-037, TASK-038, TASK-039, TASK-040, TASK-041, TASK-042, TASK-043, TASK-044, TASK-045]

**Deliverables**:
- All RSpec tests passing (unit, integration, system)
- Test coverage report ≥90% overall
- Fix any Sorcery-related failures
- Update deprecation warnings

**Commands**:
```bash
bundle exec rspec
bundle exec rspec --format documentation
bundle exec rspec --tag ~slow # Fast tests only
```

**Definition of Done**:
- All RSpec tests pass
- Code coverage ≥90%
- No deprecation warnings
- CI pipeline green

**Estimated Complexity**: High
**Assigned To**: test-worker-v1-self-adapting

---

### Phase 6: Deployment & Cleanup (TASK-047 to TASK-048)

#### TASK-047: Create Deployment Runbook
**Description**: Create comprehensive deployment runbook for production migration

**Dependencies**: [TASK-046]

**Deliverables**:
- File: `docs/deployment/rails8-auth-migration-runbook.md`
- Pre-deployment checklist (backup, verification, feature flag)
- Deployment steps (migration, code deploy, canary testing)
- Monitoring checklist (logs, metrics, error rates)
- Rollback procedure
- Post-deployment verification
- 30-day monitoring plan

**Content Outline**:
1. Pre-Deployment
   - Database backup
   - Test migration on staging
   - Verify all tests pass
   - Deploy feature flag (disabled)
2. Deployment
   - Run database migrations
   - Deploy code
   - Enable feature flag for 1% traffic
   - Monitor for 24 hours
   - Gradual rollout (10%, 50%, 100%)
3. Monitoring
   - Check authentication success rate ≥99%
   - Check login latency <500ms p95
   - Monitor account lock rate
   - Check error logs
4. Rollback (if needed)
   - Disable feature flag
   - Revert code deployment
   - Verify Sorcery still works
5. Post-Deployment (30 days)
   - Monitor authentication metrics
   - Verify no password-related support tickets
   - Schedule Sorcery column removal

**Definition of Done**:
- Runbook written
- Reviewed by team
- Tested on staging
- Approved for production

**Estimated Complexity**: Medium
**Assigned To**: backend-worker-v1-self-adapting

---

#### TASK-048: Remove Sorcery Gem and Cleanup
**Description**: Remove Sorcery gem, initializer, and deprecated code after successful production verification

**Dependencies**: [TASK-047] (30-day monitoring complete)

**Deliverables**:
- Remove `gem 'sorcery'` from Gemfile
- Delete `config/initializers/sorcery.rb`
- Run `bundle install`
- Run database migration to remove `crypted_password` and `salt` columns (TASK-007)
- Remove any Sorcery-related comments or documentation
- Update README.md with new authentication system

**Steps**:
```bash
# 1. Remove gem
# Edit Gemfile, remove sorcery line
bundle install

# 2. Remove initializer
rm config/initializers/sorcery.rb

# 3. Run cleanup migration
bin/rails db:migrate

# 4. Run tests
bundle exec rspec

# 5. Update documentation
# Edit README.md
```

**Definition of Done**:
- Sorcery gem removed
- Initializer deleted
- Deprecated columns removed
- All tests pass
- Documentation updated

**Estimated Complexity**: Low
**Assigned To**: backend-worker-v1-self-adapting

---

## 3. Execution Sequence

### Phase 1: Database Layer (Weeks 1-2)
**Critical Path**: TASK-001 → TASK-002 → TASK-003
**Parallel**:
- TASK-001, TASK-004, TASK-005, TASK-006, TASK-008 can start in parallel
- TASK-007 created but not run

```
TASK-001 (Add password_digest) ──┐
TASK-004 (Add MFA fields)        ├──→ Database ready
TASK-005 (Add OAuth fields)      │
TASK-006 (Data validator)        ┘
TASK-008 (Email validator)

TASK-001 ──→ TASK-002 (Research) ──→ TASK-003 (Migrate passwords)
TASK-003 ──→ TASK-007 (Create removal migration, don't run)
```

### Phase 2: Backend - Core Authentication (Weeks 2-4)
**Critical Path**: TASK-009 → TASK-010 → TASK-011 → TASK-012 → TASK-015 → TASK-020

**Parallel Opportunities**:
- TASK-009, TASK-013, TASK-014, TASK-017, TASK-019, TASK-023 can start in parallel
- TASK-016 depends on TASK-013
- TASK-020, TASK-021, TASK-022 depend on TASK-015

```
Parallel Start:
TASK-009 (AuthResult) ──────────┐
TASK-013 (BruteForceProtection) ├──→ TASK-010 ──→ TASK-011 ──→ TASK-012 ──→ TASK-015
TASK-014 (Authenticatable)      │
TASK-017 (SessionManager)       │
TASK-019 (Config initializer)   │
TASK-023 (I18n locales)         ┘

TASK-013 ──→ TASK-016 (Update Operator model)

TASK-015 ──→ TASK-020 (Update sessions controller)
         ├──→ TASK-021 (Update base controller)
         └──→ TASK-022 (Update application controller)

TASK-002 ──→ TASK-018 (PasswordMigrator)
```

### Phase 3: Observability Setup (Week 4)
**Parallel**: All observability tasks can run in parallel

```
TASK-024 (Lograge)         ──┐
TASK-025 (StatsD)          ──┤
TASK-026 (Request correlation) ├──→ TASK-028 (Documentation)
TASK-027 (Prometheus)      ──┘
```

### Phase 4: Frontend Updates (Week 5)
**Parallel**: All frontend tasks can run in parallel

```
TASK-029 (Login form)      ──┐
TASK-030 (Routes)          ──┤
TASK-031 (Flash messages)  ──├──→ Frontend ready
TASK-032 (Locked page)     ──┤
TASK-033 (Logout link)     ──┤
TASK-034 (MFA form)        ──┘
```

### Phase 5: Testing (Weeks 5-7)
**Critical Path**: All tests must pass before deployment

**Parallel Opportunities**:
- TASK-035, TASK-037, TASK-040, TASK-043, TASK-044 can start in parallel
- TASK-036, TASK-038, TASK-039 depend on implementation tasks
- TASK-046 waits for all tests

```
Parallel Start:
TASK-035 (Model specs)         ──┐
TASK-037 (Concern specs)       ──┤
TASK-040 (Migration specs)     ──┤
TASK-043 (Factory updates)     ──├──→ TASK-046 (Full test suite)
TASK-044 (Helper updates)      ──┤
TASK-036 (Service specs)       ──┤
TASK-038 (Controller specs)    ──┤
TASK-039 (System specs)        ──┤
TASK-041 (Observability specs) ──┤
TASK-042 (Security specs)      ──┤
TASK-045 (Performance benchmarks) ┘
```

### Phase 6: Deployment & Cleanup (Weeks 7-9)
**Sequential**: Must follow exact order

```
TASK-046 (All tests pass) ──→ TASK-047 (Deployment runbook)
                          ──→ Production deployment
                          ──→ 30-day monitoring
                          ──→ TASK-048 (Remove Sorcery)
```

---

## 4. Risk Assessment

### Technical Risks

**R-1: Password Hash Incompatibility (High Impact, Medium Probability)**
- **Risk**: Sorcery's bcrypt format may not be directly compatible with Rails 8
- **Mitigation**: TASK-002 research phase validates compatibility before migration
- **Contingency**: Implement custom password rehashing strategy if needed
- **Tasks Affected**: TASK-003, TASK-018

**R-2: Session Invalidation During Migration (Medium Impact, Low Probability)**
- **Risk**: Active sessions may be invalidated during database migration
- **Mitigation**: Feature flag deployment, gradual rollout
- **Contingency**: Notify users to re-login after deployment
- **Tasks Affected**: TASK-047

**R-3: Brute Force Protection Regression (High Impact, Low Probability)**
- **Risk**: Account locking may not work correctly after migration
- **Mitigation**: Comprehensive tests in TASK-037, TASK-038, TASK-042
- **Contingency**: Rollback deployment, fix and redeploy
- **Tasks Affected**: TASK-013, TASK-037

**R-4: Performance Degradation (Medium Impact, Low Probability)**
- **Risk**: Authentication may be slower than Sorcery
- **Mitigation**: Performance benchmarks in TASK-045 (target: <500ms p95)
- **Contingency**: Optimize bcrypt cost factor, add database indexes
- **Tasks Affected**: TASK-045

### Dependency Risks

**R-5: Test Coverage Gaps (Medium Impact, Medium Probability)**
- **Risk**: Missing test coverage could allow bugs into production
- **Mitigation**: Coverage target ≥90% in TASK-046
- **Contingency**: Add missing tests before deployment
- **Tasks Affected**: All testing tasks (TASK-035 to TASK-046)

**R-6: I18n Translation Errors (Low Impact, Medium Probability)**
- **Risk**: Japanese translations may have errors or be incomplete
- **Mitigation**: Review by native speaker, test all UI flows
- **Contingency**: Hotfix translations after deployment
- **Tasks Affected**: TASK-023, TASK-029, TASK-032, TASK-034

**R-7: Observability Setup Complexity (Low Impact, Medium Probability)**
- **Risk**: Lograge/StatsD configuration may be complex in production
- **Mitigation**: Test on staging, document thoroughly in TASK-028
- **Contingency**: Deploy without observability, add later
- **Tasks Affected**: TASK-024, TASK-025, TASK-026, TASK-027

---

## 5. Success Metrics

**Functional Success**:
- ✅ All existing operators can log in with current credentials (100% migration)
- ✅ Brute force protection locks accounts after 5 failed attempts
- ✅ Email notifications sent on locked account access
- ✅ All RSpec tests pass (unit + integration + system)

**Technical Success**:
- ✅ Sorcery gem removed from Gemfile
- ✅ Authentication latency <500ms (p95)
- ✅ Code coverage ≥90%
- ✅ Zero authentication-related errors in production logs (first 7 days)

**Security Success**:
- ✅ Brakeman security scan passes with no critical issues
- ✅ Bcrypt cost factor ≥12 in production
- ✅ Session fixation prevention verified
- ✅ CSRF protection verified

**Observability Success**:
- ✅ Structured JSON logs include request_id, event, result, reason
- ✅ StatsD metrics tracked: auth.attempts, auth.success, auth.failures, auth.duration
- ✅ Prometheus /metrics endpoint accessible and secured
- ✅ Grafana dashboard showing authentication metrics

---

## 6. Dependencies and Prerequisites

**External Dependencies**:
- ✅ Rails 8.1.1 (already upgraded)
- ✅ Ruby 3.4.6 (already upgraded)
- ✅ MySQL 8.0 (dev/test)
- ✅ PostgreSQL (production)
- ✅ Pundit gem (unchanged)

**New Gem Dependencies**:
- `bcrypt` (already present for Sorcery, verify version)
- `lograge` (for structured logging)
- `statsd-instrument` (for metrics)
- `request_store` (for request correlation)
- `prometheus_exporter` (for metrics endpoint)
- `rspec-benchmark` (for performance tests)

**Environment Variables Required**:
- `LOGIN_RETRY_LIMIT` (default: 5)
- `LOGIN_LOCK_DURATION` (default: 45 minutes)
- `PASSWORD_MIN_LENGTH` (default: 8)
- `SESSION_TIMEOUT` (default: 30 minutes)
- `SESSION_ABSOLUTE_TIMEOUT` (default: 24 hours)
- `BCRYPT_COST` (default: 12 for production, 1 for test)
- `AUTH_OAUTH_ENABLED` (default: false)
- `AUTH_MFA_ENABLED` (default: false)
- `STATSD_HOST` (default: localhost)
- `STATSD_PORT` (default: 8125)
- `METRICS_TOKEN` (required for /metrics endpoint)

---

## 7. Parallel Execution Opportunities

**Week 1-2 (Database Layer)**:
- Parallel: TASK-001, TASK-004, TASK-005, TASK-006, TASK-008 (5 tasks)

**Week 2-4 (Backend Core)**:
- Parallel: TASK-009, TASK-013, TASK-014, TASK-017, TASK-019, TASK-023 (6 tasks)
- Parallel: TASK-020, TASK-021, TASK-022 (3 tasks, after TASK-015)

**Week 4 (Observability)**:
- Parallel: TASK-024, TASK-025, TASK-026, TASK-027 (4 tasks)

**Week 5 (Frontend)**:
- Parallel: TASK-029, TASK-030, TASK-031, TASK-032, TASK-033, TASK-034 (6 tasks)

**Week 5-7 (Testing)**:
- Parallel: TASK-035, TASK-036, TASK-037, TASK-038, TASK-039, TASK-040, TASK-041, TASK-042, TASK-043, TASK-044, TASK-045 (11 tasks)

**Total Parallel Opportunities**: 35 out of 48 tasks can be parallelized (73%)

---

## 8. Critical Path

```
Week 1-2:
TASK-001 (Add password_digest)
  ↓
TASK-002 (Research Sorcery compatibility)
  ↓
TASK-003 (Migrate password hashes)

Week 2-3:
TASK-009 (AuthResult)
  ↓
TASK-010 (Provider base class)
  ↓
TASK-011 (PasswordProvider)
  ↓
TASK-012 (AuthenticationService)

Week 3-4:
TASK-013 (BruteForceProtection)
  ↓
TASK-016 (Update Operator model)
  ↓
TASK-015 (Authentication concern)
  ↓
TASK-020 (Update sessions controller)

Week 5:
TASK-029 to TASK-034 (Frontend updates - parallel)

Week 5-7:
TASK-035 to TASK-045 (Testing - parallel)
  ↓
TASK-046 (Full test suite)

Week 7-9:
TASK-047 (Deployment runbook)
  ↓
Production deployment (feature flag, canary, gradual rollout)
  ↓
30-day monitoring
  ↓
TASK-048 (Remove Sorcery)
```

**Critical Path Duration**: 42 days (9 weeks)

---

## 9. Task Assignment Summary

**database-worker-v1-self-adapting** (8 tasks):
- TASK-001, TASK-003, TASK-004, TASK-005, TASK-007

**backend-worker-v1-self-adapting** (20 tasks):
- TASK-002, TASK-006, TASK-008, TASK-009, TASK-010, TASK-011, TASK-012, TASK-013, TASK-014, TASK-015, TASK-016, TASK-017, TASK-018, TASK-019, TASK-020, TASK-021, TASK-022, TASK-023, TASK-024, TASK-025, TASK-026, TASK-027, TASK-028, TASK-047, TASK-048

**frontend-worker-v1-self-adapting** (6 tasks):
- TASK-029, TASK-030, TASK-031, TASK-032, TASK-033, TASK-034

**test-worker-v1-self-adapting** (14 tasks):
- TASK-035, TASK-036, TASK-037, TASK-038, TASK-039, TASK-040, TASK-041, TASK-042, TASK-043, TASK-044, TASK-045, TASK-046

---

## 10. Definition of Done (Overall)

**Phase 1: Database Layer**:
- ✅ All migrations created and tested on development database
- ✅ Password migration strategy validated with test data
- ✅ Sorcery compatibility research complete
- ✅ MFA and OAuth fields added (future-ready)

**Phase 2: Backend Core**:
- ✅ All authentication services and concerns implemented
- ✅ Operator model uses has_secure_password
- ✅ Controllers use Authentication concern
- ✅ I18n translations complete (Japanese + English)
- ✅ Configuration uses ENV variables

**Phase 3: Observability**:
- ✅ Lograge configured for JSON logs
- ✅ StatsD metrics instrumented
- ✅ Request correlation implemented
- ✅ Prometheus /metrics endpoint secured
- ✅ Documentation complete

**Phase 4: Frontend**:
- ✅ All views updated with I18n
- ✅ Login/logout flows work correctly
- ✅ Flash messages display properly
- ✅ Cat emoji messages preserved

**Phase 5: Testing**:
- ✅ All RSpec tests pass (unit + integration + system)
- ✅ Code coverage ≥90%
- ✅ Security tests pass (Brakeman, penetration tests)
- ✅ Performance benchmarks meet targets (<500ms p95)

**Phase 6: Deployment**:
- ✅ Deployment runbook created and tested
- ✅ Production deployment successful (feature flag, canary, gradual rollout)
- ✅ 30-day monitoring period complete with no issues
- ✅ Sorcery gem and columns removed
- ✅ Documentation updated

---

**This task plan is ready for evaluation by planner-evaluators.**
