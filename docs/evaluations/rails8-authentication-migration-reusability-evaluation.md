# Design Reusability Evaluation - Rails 8 Authentication Migration

**Evaluator**: design-reusability-evaluator
**Design Document**: /Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/rails8-authentication-migration.md
**Evaluated**: 2025-11-24T10:30:00+09:00

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 3.6 / 5.0

---

## Detailed Scores

### 1. Component Generalization: 3.5 / 5.0 (Weight: 35%)

**Findings**:
The design demonstrates **moderate generalization** with some components designed for reuse, but several feature-specific implementations limit broader applicability:

**Well-Generalized Components**:
- `Authentication` concern provides reusable authentication methods (`authenticate_operator`, `login`, `logout`, `current_operator`)
- `BruteForceProtection` concern is well-abstracted with configurable constants (`CONSECUTIVE_LOGIN_RETRIES_LIMIT`, `LOGIN_LOCK_TIME_PERIOD`)
- Password validation logic uses standard Rails patterns (`has_secure_password`)

**Poorly Generalized Components**:
- **Hardcoded values**: Japanese UI messages ("キャットイン", "キャットアウト") embedded in controller logic
- **Feature-specific naming**: `operator_cat_in_path`, `operator_cat_out_path` - not reusable naming convention
- **Tight coupling to Operator model**: `authenticate_operator`, `current_operator` - cannot be reused for other user types (e.g., Admin, Customer)
- **Email notification logic**: `SessionMailer.notice` hardcoded in BruteForceProtection concern - should be injectable

**Issues**:
1. Authentication concern is tightly coupled to "Operator" model name - should be parameterized
2. Japanese UI messages hardcoded in controllers - should use I18n properly
3. Brute force protection mailer is hardcoded - should be configurable
4. No generic session management abstraction - specific to operator namespace only
5. Path helpers are feature-specific (`operator_cat_in_path`) - not reusable

**Recommendation**:
Extract to fully reusable components:

```ruby
# Reusable Authentication Concern
module Authenticatable
  extend ActiveSupport::Concern

  included do
    class_attribute :authenticatable_model, :authenticatable_path_prefix
    before_action :set_current_user
    helper_method :current_user, :user_signed_in?
  end

  class_methods do
    def authenticates_with(model:, path_prefix: nil)
      self.authenticatable_model = model
      self.authenticatable_path_prefix = path_prefix || model.model_name.route_key
    end
  end

  def authenticate_user(email, password)
    user = authenticatable_model.find_by(email: email.downcase)
    return nil unless user

    if user.respond_to?(:locked?) && user.locked?
      user.send_lock_notification(request.remote_ip) if user.respond_to?(:send_lock_notification)
      return nil
    end

    if user.authenticate(password)
      user.reset_failed_logins! if user.respond_to?(:reset_failed_logins!)
      user
    else
      user.increment_failed_logins! if user.respond_to?(:increment_failed_logins!)
      nil
    end
  end

  def login(user)
    reset_session
    session[:user_id] = user.id
    session[:user_type] = user.class.name
    @current_user = user
  end
end

# Usage in OperatorSessionsController
class Operator::OperatorSessionsController < Operator::BaseController
  authenticates_with model: Operator, path_prefix: 'operator'

  def create
    operator = authenticate_user(params[:email], params[:password])
    if operator
      login(operator)
      redirect_to operator_operates_path, success: t('operator.sessions.login_success')
    else
      flash.now[:alert] = t('operator.sessions.login_failure')
      render :new, status: :unprocessable_entity
    end
  end
end

# Reusable BruteForceProtection with dependency injection
module BruteForceProtection
  extend ActiveSupport::Concern

  included do
    class_attribute :lock_retry_limit, :lock_duration, :lock_notifier
    self.lock_retry_limit = 5
    self.lock_duration = 45.minutes
    self.lock_notifier = nil # Can be set to a callable (lambda, proc, or service object)
  end

  def locked?
    lock_expires_at.present? && lock_expires_at > Time.current
  end

  def increment_failed_logins!
    increment!(:failed_logins_count)
    lock_account! if failed_logins_count >= lock_retry_limit
  end

  def send_lock_notification(ip_address)
    lock_notifier&.call(self, ip_address) if locked?
  end

  # ... rest of methods
end

# Configure in Operator model
class Operator < ApplicationRecord
  include BruteForceProtection

  self.lock_retry_limit = 5
  self.lock_duration = 45.minutes
  self.lock_notifier = ->(operator, ip) { SessionMailer.notice(operator, ip).deliver_later }
end
```

**Reusability Potential**:
- `Authentication` concern → Can be extracted to shared gem/engine for multi-tenant apps
- `BruteForceProtection` concern → Can be reused for Customer, Admin, Vendor models
- Password migration strategy → Can be template for other Sorcery→Rails8 migrations

**Weighted Score Calculation**: 3.5 * 0.35 = 1.225

---

### 2. Business Logic Independence: 3.8 / 5.0 (Weight: 30%)

**Findings**:
Business logic shows **good separation** from presentation layer, but some coupling to Rails framework remains:

**Well-Separated Logic**:
- `BruteForceProtection` concern is UI-agnostic - can run in background jobs, CLI, API
- Password authentication logic (`has_secure_password`) is framework-agnostic
- Account locking mechanism is independent of HTTP layer
- Email notification is abstracted via mailer (not inline in controller)

**Moderate Coupling**:
- Authentication concern uses `session` (HTTP-specific) - cannot reuse in API-only mode without modification
- `request.remote_ip` directly accessed in authentication flow - should be parameter
- Flash messages handled in controller - appropriate but not reusable in API context
- Redirect logic embedded in controllers - cannot reuse in GraphQL/API contexts

**Issues**:
1. Session management tied to HTTP sessions - cannot reuse for JWT/token-based auth
2. `request.remote_ip` accessed directly - should be passed as parameter for API compatibility
3. Authentication concern mixes HTTP concerns (session, redirect) with business logic
4. No service layer abstraction - business logic scattered across concern and model

**Recommendation**:
Separate business logic into service layer:

```ruby
# Pure business logic service (framework-agnostic)
class AuthenticationService
  class << self
    def authenticate(user_class, email, password, ip_address: nil)
      user = user_class.find_by(email: email.downcase)
      return AuthResult.failed(:user_not_found) unless user

      if user.respond_to?(:locked?) && user.locked?
        user.send_lock_notification(ip_address) if ip_address && user.respond_to?(:send_lock_notification)
        return AuthResult.failed(:account_locked, user: user)
      end

      if user.authenticate(password)
        user.reset_failed_logins! if user.respond_to?(:reset_failed_logins!)
        AuthResult.success(user: user)
      else
        user.increment_failed_logins! if user.respond_to?(:increment_failed_logins!)
        AuthResult.failed(:invalid_credentials, user: user)
      end
    end
  end

  class AuthResult
    attr_reader :status, :user, :reason

    def self.success(user:)
      new(status: :success, user: user)
    end

    def self.failed(reason, user: nil)
      new(status: :failed, reason: reason, user: user)
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
      !success?
    end
  end
end

# HTTP Controller (presentation layer)
class Operator::OperatorSessionsController < Operator::BaseController
  def create
    result = AuthenticationService.authenticate(
      Operator,
      params[:email],
      params[:password],
      ip_address: request.remote_ip
    )

    if result.success?
      login(result.user)
      redirect_to operator_operates_path, success: t('operator.sessions.login_success')
    else
      flash.now[:alert] = error_message_for(result.reason)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def error_message_for(reason)
    case reason
    when :account_locked
      t('operator.sessions.account_locked')
    else
      t('operator.sessions.login_failure')
    end
  end
end

# API Controller (API layer - can reuse same service)
class Api::V1::SessionsController < Api::V1::BaseController
  def create
    result = AuthenticationService.authenticate(
      Operator,
      params[:email],
      params[:password],
      ip_address: request.remote_ip
    )

    if result.success?
      token = generate_jwt_token(result.user)
      render json: { token: token, user: result.user.as_json }
    else
      render json: { error: result.reason }, status: :unauthorized
    end
  end
end
```

**Portability Assessment**:
- Can this logic run in CLI? **Partially** - needs service layer extraction
- Can this logic run in mobile app backend (API)? **Partially** - session dependency prevents direct reuse
- Can this logic run in background job? **Yes** - BruteForceProtection logic is independent

**Weighted Score Calculation**: 3.8 * 0.30 = 1.14

---

### 3. Domain Model Abstraction: 3.5 / 5.0 (Weight: 20%)

**Findings**:
Domain models show **moderate abstraction** with some Rails framework dependencies:

**Well-Abstracted**:
- `Operator` model uses plain ActiveRecord without heavy framework coupling
- Password validation logic uses standard `has_secure_password` (minimal dependency)
- Brute force protection fields are database-agnostic (works with MySQL and PostgreSQL)
- Email normalization logic is framework-agnostic

**Framework Dependencies**:
- `has_secure_password` ties model to bcrypt gem (acceptable Rails convention)
- ActiveRecord validations are Rails-specific (but standard practice)
- Enum usage (`enum :role`) is Rails-specific (but portable across Rails apps)
- `update_columns` vs `update` - Rails-specific performance optimization

**Issues**:
1. Model directly depends on `SessionMailer` in `mail_notice` method - should be injected
2. No interface/abstract class for authenticatable models - tight coupling to Operator
3. Concern logic assumes ActiveRecord methods (`increment!`, `update_columns`) - cannot port to ROM, Sequel
4. No domain events - difficult to extend without modifying model code

**Recommendation**:
Improve abstraction:

```ruby
# Domain model with minimal framework dependencies
class Operator < ApplicationRecord
  # Authentication
  has_secure_password

  # Concerns (portable across Rails apps)
  include BruteForceProtection
  include Notifiable  # New abstraction

  # Enums
  enum :role, { operator: 0, guest: 1 }

  # Validations (standard Rails - acceptable)
  validates :name, presence: true, length: { in: 2..255 }
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: /\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/ }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :role, presence: true

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.downcase if email.present?
  end
end

# Extract notification concern (allows different notification strategies)
module Notifiable
  extend ActiveSupport::Concern

  included do
    class_attribute :notifiers
    self.notifiers = {}
  end

  class_methods do
    def notify_on(event, notifier:)
      self.notifiers[event] = notifier
    end
  end

  def notify(event, **args)
    notifier = self.class.notifiers[event]
    notifier&.call(self, **args)
  end
end

# Configure in Operator model
class Operator < ApplicationRecord
  include Notifiable

  notify_on :account_locked, notifier: ->(operator, ip:) {
    SessionMailer.notice(operator, ip).deliver_later
  }
end

# BruteForceProtection concern uses notification abstraction
module BruteForceProtection
  def send_lock_notification(ip_address)
    notify(:account_locked, ip: ip_address) if locked?
  end
end
```

**Persistence Layer Portability**:
- Can switch from PostgreSQL to MongoDB? **No** - uses ActiveRecord-specific methods
- Can switch from ActiveRecord to ROM? **No** - tight coupling to AR methods
- Can use models in different Rails apps? **Yes** - standard Rails patterns
- Can models be used without database (in-memory)? **No** - requires AR persistence

**Weighted Score Calculation**: 3.5 * 0.20 = 0.70

---

### 4. Shared Utility Design: 3.5 / 5.0 (Weight: 15%)

**Findings**:
Shared utilities show **moderate design** with some extraction but missing common patterns:

**Existing Utilities**:
- `Authentication` concern extracts common authentication patterns
- `BruteForceProtection` concern extracts account locking logic
- `SessionMailer` abstracts email sending

**Missing Utilities**:
- **No generic password migration utility** - migration code is specific to Operator model, should be reusable for other models
- **No session management utility** - session reset, creation, destruction logic could be extracted
- **No validation helpers** - email format validation regex should be extracted to shared utility
- **No error response builder** - error message mapping is duplicated across controllers
- **No authentication result object** - success/failure handling logic is ad-hoc

**Code Duplication Detected**:
1. Email format validation regex `/\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/` - should be `EmailValidator` utility
2. Session reset logic (`reset_session` + `session[:operator_id] = nil`) - should be `SessionManager` utility
3. Error message mapping (in controllers) - should be `ErrorPresenter` utility
4. Checksum validation logic (in migration) - should be `DataMigrationValidator` utility

**Recommendation**:
Extract utilities:

```ruby
# app/lib/validators/email_validator.rb
module Validators
  class EmailValidator
    EMAIL_FORMAT = /\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/

    def self.valid?(email)
      email.present? && email.match?(EMAIL_FORMAT)
    end

    def self.normalize(email)
      email&.downcase&.strip
    end
  end
end

# app/services/session_manager.rb
class SessionManager
  def initialize(session)
    @session = session
  end

  def login(user, user_type: nil)
    reset
    @session[:user_id] = user.id
    @session[:user_type] = user_type || user.class.name
  end

  def logout
    reset
  end

  def current_user_id
    @session[:user_id]
  end

  def current_user_type
    @session[:user_type]
  end

  def reset
    @session.clear
  end
end

# app/lib/data_migration_validator.rb
class DataMigrationValidator
  def self.generate_checksum(records, attributes)
    records.map do |record|
      data = attributes.map { |attr| record.send(attr) }.join(':')
      Digest::SHA256.hexdigest(data)
    end
  end

  def self.verify_count(before_count, after_count, model_name)
    raise "Migration failed: #{model_name} count mismatch (before: #{before_count}, after: #{after_count})" if before_count != after_count
  end
end

# app/services/password_migrator.rb
class PasswordMigrator
  def self.migrate_from_sorcery(model_class, from_field: :crypted_password, to_field: :password_digest)
    model_class.find_each do |record|
      if record.send(from_field).present?
        record.update_column(to_field, record.send(from_field))
      end
    end
  end

  def self.validate_migration(model_class, sample_credentials)
    sample_credentials.each do |email, password|
      user = model_class.find_by(email: email)
      raise "Migration validation failed for #{email}" unless user&.authenticate(password)
    end
  end
end

# app/presenters/authentication_error_presenter.rb
class AuthenticationErrorPresenter
  def self.message_for(reason, locale: I18n.locale)
    I18n.t("authentication.errors.#{reason}", locale: locale, default: I18n.t('authentication.errors.generic', locale: locale))
  end
end
```

**Potential Utilities**:
- Extract `PasswordMigrator` for generic Sorcery→Rails8 migrations
- Extract `SessionManager` for consistent session handling
- Extract `EmailValidator` for email validation across models
- Extract `DataMigrationValidator` for safe data migrations
- Extract `AuthenticationErrorPresenter` for consistent error messaging

**Weighted Score Calculation**: 3.5 * 0.15 = 0.525

---

## Reusability Opportunities

### High Potential
1. **BruteForceProtection concern** - Can be shared across Admin, Customer, Vendor models with minor refactoring (remove hardcoded mailer)
2. **Password migration strategy** - Can be template for other Sorcery→Rails8 migrations in organization
3. **Authentication service layer** (if extracted) - Can be reused for multi-tenant applications, API authentication

### Medium Potential
1. **Authentication concern** - Needs parameterization to support different model types (currently Operator-specific)
2. **Email validation logic** - Should be extracted to shared utility for reuse across models
3. **Session management logic** - Can be extracted to utility for consistent session handling

### Low Potential (Feature-Specific)
1. **Japanese UI messages** - Inherently feature-specific, but should use I18n for better maintainability
2. **Operator model structure** - Domain-specific, acceptable to be feature-specific
3. **SessionMailer** - Feature-specific notification logic, acceptable

---

## Reusability Metrics

### Component Reusability Analysis

**Reusable Components**: 3/10
- `Authentication` concern (partially reusable - needs refactoring)
- `BruteForceProtection` concern (partially reusable - hardcoded mailer)
- `has_secure_password` usage (fully reusable - standard Rails)

**Feature-Specific Components**: 7/10
- `Operator` model (domain-specific)
- `OperatorSessionsController` (feature-specific routing/naming)
- `SessionMailer` (feature-specific notification)
- Japanese UI messages (feature-specific localization)
- Migration scripts (migration-specific)
- Path helpers (`operator_cat_in_path`) (feature-specific naming)
- Test helpers (feature-specific)

**Reusable Component Ratio**: 30%

---

## Action Items for Designer

Since status is "Request Changes", the designer should:

### Priority 1: Generalize Authentication Components

1. **Refactor Authentication concern** to support multiple model types:
   - Use `authenticatable_model` class attribute for model configuration
   - Replace `current_operator` with generic `current_user`
   - Support both session-based and token-based authentication

2. **Extract AuthenticationService** for framework-agnostic business logic:
   - Remove HTTP dependencies (session, request) from service layer
   - Return result objects instead of nil/user
   - Support CLI, API, background job contexts

### Priority 2: Remove Hardcoded Dependencies

3. **Remove hardcoded mailer** from BruteForceProtection concern:
   - Use dependency injection pattern (class attribute or lambda)
   - Allow different notification strategies per model

4. **Extract I18n keys** for all user-facing messages:
   - Move Japanese messages to locale files
   - Use `t()` helper consistently
   - Support multi-locale applications

### Priority 3: Create Shared Utilities

5. **Extract reusable utilities**:
   - Create `EmailValidator` for email format validation
   - Create `SessionManager` for session lifecycle management
   - Create `PasswordMigrator` for generic password migrations
   - Create `DataMigrationValidator` for migration safety checks

### Priority 4: Improve Model Abstraction

6. **Reduce model framework coupling**:
   - Extract notification logic to separate concern with injectable notifiers
   - Consider domain events for extensibility
   - Document portability limitations (ActiveRecord-specific)

### Documentation Required

7. **Document reusability guidelines**:
   - How to reuse Authentication concern for other models (Admin, Customer)
   - How to configure BruteForceProtection for different thresholds
   - How to use PasswordMigrator for other Sorcery migrations
   - Migration rollback procedures

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-reusability-evaluator"
  design_document: "/Users/yujitsuchiya/cat_salvages_the_relationship/docs/designs/rails8-authentication-migration.md"
  timestamp: "2025-11-24T10:30:00+09:00"
  overall_judgment:
    status: "Request Changes"
    overall_score: 3.6
  detailed_scores:
    component_generalization:
      score: 3.5
      weight: 0.35
      weighted_score: 1.225
    business_logic_independence:
      score: 3.8
      weight: 0.30
      weighted_score: 1.14
    domain_model_abstraction:
      score: 3.5
      weight: 0.20
      weighted_score: 0.70
    shared_utility_design:
      score: 3.5
      weight: 0.15
      weighted_score: 0.525
  reusability_opportunities:
    high_potential:
      - component: "BruteForceProtection concern"
        contexts: ["Admin model", "Customer model", "Vendor model", "API authentication"]
        refactoring_needed: "Remove hardcoded mailer dependency"
      - component: "Password migration strategy"
        contexts: ["Other Sorcery migrations", "Legacy authentication upgrades", "Framework migrations"]
        refactoring_needed: "Extract to PasswordMigrator utility"
      - component: "Authentication service layer"
        contexts: ["Multi-tenant apps", "API authentication", "CLI tools", "Background jobs"]
        refactoring_needed: "Extract from concern to service class"
    medium_potential:
      - component: "Authentication concern"
        contexts: ["Other user types", "Multi-model authentication", "API controllers"]
        refactoring_needed: "Parameterize model type, remove Operator-specific naming"
      - component: "Email validation logic"
        contexts: ["Other models with email", "API validation", "Shared gems"]
        refactoring_needed: "Extract to EmailValidator utility"
      - component: "Session management logic"
        contexts: ["Other controllers", "API token management", "Multi-session support"]
        refactoring_needed: "Extract to SessionManager utility"
    low_potential:
      - component: "Japanese UI messages"
        reason: "Feature-specific localization"
        recommendation: "Use I18n for better maintainability"
      - component: "Operator model structure"
        reason: "Domain-specific business entity"
        recommendation: "Acceptable to be feature-specific"
      - component: "SessionMailer"
        reason: "Feature-specific notification logic"
        recommendation: "Acceptable with dependency injection pattern"
  reusable_component_ratio: 0.30
  code_duplication:
    instances:
      - pattern: "Email format validation regex"
        occurrences: 1
        recommendation: "Extract to EmailValidator utility"
      - pattern: "Session reset logic"
        occurrences: 2
        recommendation: "Extract to SessionManager utility"
      - pattern: "Error message mapping"
        occurrences: 2
        recommendation: "Extract to ErrorPresenter utility"
      - pattern: "Checksum validation"
        occurrences: 1
        recommendation: "Extract to DataMigrationValidator utility"
  portability_assessment:
    can_run_in_cli: "Partially - needs service layer extraction"
    can_run_in_api: "Partially - session dependency limits reuse"
    can_run_in_background_job: "Yes - business logic is independent"
    can_use_in_other_rails_apps: "Yes - with minor configuration"
    can_use_in_non_rails_apps: "No - tight Rails/ActiveRecord coupling"
  recommendations:
    priority_1:
      - "Refactor Authentication concern to support multiple model types"
      - "Extract AuthenticationService for framework-agnostic business logic"
    priority_2:
      - "Remove hardcoded mailer from BruteForceProtection concern"
      - "Extract I18n keys for all user-facing messages"
    priority_3:
      - "Create shared utilities (EmailValidator, SessionManager, PasswordMigrator, DataMigrationValidator)"
    priority_4:
      - "Reduce model framework coupling with injectable dependencies"
      - "Document reusability guidelines and usage examples"
```
