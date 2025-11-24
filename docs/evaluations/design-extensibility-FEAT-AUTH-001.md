# Design Extensibility Evaluation - Rails 8 Authentication Migration

**Evaluator**: design-extensibility-evaluator
**Design Document**: docs/designs/rails8-authentication-migration.md
**Evaluated**: 2025-11-24T10:30:00+09:00
**Feature ID**: FEAT-AUTH-001

---

## Overall Judgment

**Status**: Request Changes
**Overall Score**: 6.5 / 10.0

**Summary**: The design provides a **solid foundation** for Rails 8 authentication with good security practices and comprehensive brute force protection. However, it lacks critical abstractions for future authentication methods (OAuth, SAML, MFA) and has several hardcoded implementations that will make future extensions difficult. The migration strategy is well-thought-out, but the final architecture does not adequately prepare for anticipated authentication enhancements.

---

## Detailed Scores

### 1. Interface Design: 5.0 / 10.0 (Weight: 35%)

**Findings**:
- ❌ **No AuthenticationProvider abstraction** - Password authentication hardcoded
- ❌ **No PasswordHasher interface** - bcrypt implementation directly coupled
- ❌ **No EmailService abstraction** - SessionMailer tightly coupled
- ❌ **No SessionStore interface** - Cookie-based storage hardcoded
- ✅ **BruteForceProtection extracted as concern** - Good separation
- ⚠️ **Authentication concern mixed responsibilities** - Auth + session + brute force

**Critical Issues**:

#### 1.1 Missing AuthenticationProvider Abstraction

**Problem**: Password authentication logic is hardcoded in the Authentication concern (lines 564-583).

**Current Implementation**:
```ruby
# app/controllers/concerns/authentication.rb
def authenticate_operator(email, password)
  operator = Operator.find_by(email: email.downcase)
  return nil unless operator

  # HARDCODED: Only supports password authentication
  if operator.authenticate(password)
    operator.reset_failed_logins!
    operator
  else
    operator.increment_failed_logins!
    nil
  end
end
```

**Impact on Future Extensibility**:
- **Adding OAuth**: Requires modifying Authentication concern
- **Adding SAML**: Requires modifying Authentication concern
- **Adding LDAP**: Requires modifying Authentication concern
- **Adding Passwordless**: Requires modifying Authentication concern

**Recommended Solution**:
```ruby
# app/services/authentication/provider.rb (NEW)
module Authentication
  class Provider
    def authenticate(identifier, credential)
      raise NotImplementedError
    end

    def supports?(credential_type)
      raise NotImplementedError
    end
  end
end

# app/services/authentication/password_provider.rb (NEW)
module Authentication
  class PasswordProvider < Provider
    def authenticate(email, password)
      operator = Operator.find_by(email: email.downcase)
      return nil unless operator

      operator.authenticate(password) ? operator : nil
    end

    def supports?(credential_type)
      credential_type == :password
    end
  end
end

# app/services/authentication/oauth_provider.rb (FUTURE)
module Authentication
  class OAuthProvider < Provider
    def authenticate(provider, token)
      # OAuth implementation
    end

    def supports?(credential_type)
      credential_type == :oauth
    end
  end
end

# app/controllers/concerns/authentication.rb (MODIFIED)
def authenticate_operator(credential_type, **credentials)
  provider = AuthenticationProviderFactory.create(credential_type)
  operator = provider.authenticate(**credentials)

  if operator
    operator.reset_failed_logins!
    operator
  else
    operator&.increment_failed_logins!
    nil
  end
end
```

**Future Scenario - Adding OAuth**:
```ruby
# Just implement the interface - no changes to controller
class GoogleOAuthProvider < Authentication::Provider
  def authenticate(id_token:)
    payload = verify_google_token(id_token)
    Operator.find_or_create_by(email: payload['email']) do |op|
      op.name = payload['name']
      op.oauth_provider = 'google'
      op.oauth_uid = payload['sub']
    end
  end
end

# In controller:
operator = authenticate_operator(:oauth, id_token: params[:id_token])
```

**Current Effort to Add OAuth**: **Very High** (extensive refactoring)
**With Abstraction**: **Low** (implement provider interface)

---

#### 1.2 Missing PasswordHasher Abstraction

**Problem**: bcrypt is hardcoded via `has_secure_password` (line 637).

**Current Implementation**:
```ruby
# app/models/operator.rb
class Operator < ApplicationRecord
  has_secure_password  # HARDCODED: bcrypt only
end
```

**Impact on Future Extensibility**:
- **Switching to Argon2**: Requires replacing `has_secure_password`
- **Supporting multiple hash algorithms**: Not possible (migration scenario)
- **Custom password policies**: Limited flexibility

**Recommended Solution**:
```ruby
# app/services/password_hasher.rb (NEW)
class PasswordHasher
  def hash(password)
    raise NotImplementedError
  end

  def verify(password, digest)
    raise NotImplementedError
  end
end

# app/services/bcrypt_hasher.rb (NEW)
class BcryptHasher < PasswordHasher
  def hash(password)
    BCrypt::Password.create(password, cost: cost_for_environment)
  end

  def verify(password, digest)
    BCrypt::Password.new(digest) == password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  private

  def cost_for_environment
    Rails.env.test? ? 1 : 12
  end
end

# app/services/argon2_hasher.rb (FUTURE)
class Argon2Hasher < PasswordHasher
  def hash(password)
    Argon2::Password.create(password)
  end

  def verify(password, digest)
    Argon2::Password.verify_password(password, digest)
  end
end

# app/models/operator.rb (MODIFIED)
class Operator < ApplicationRecord
  attr_accessor :password, :password_confirmation

  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :password_confirmation, presence: true, if: -> { password.present? }

  before_save :hash_password, if: -> { password.present? }

  def authenticate(password)
    hasher = PasswordHasherFactory.create
    hasher.verify(password, password_digest) ? self : false
  end

  private

  def hash_password
    hasher = PasswordHasherFactory.create
    self.password_digest = hasher.hash(password)
  end
end
```

**Future Scenario - Switching to Argon2**:
```ruby
# Just configure the factory - no changes to model
class PasswordHasherFactory
  def self.create
    algorithm = ENV.fetch('PASSWORD_ALGORITHM', 'bcrypt')
    case algorithm
    when 'bcrypt' then BcryptHasher.new
    when 'argon2' then Argon2Hasher.new
    else raise "Unknown algorithm: #{algorithm}"
    end
  end
end

# In environment configuration:
export PASSWORD_ALGORITHM=argon2
```

**Current Effort to Switch Hash Algorithm**: **Very High** (replace has_secure_password)
**With Abstraction**: **Low** (implement hasher interface, configure factory)

---

#### 1.3 Missing EmailService Abstraction

**Problem**: Email delivery is hardcoded to `SessionMailer` (line 709).

**Current Implementation**:
```ruby
# app/models/concerns/brute_force_protection.rb
def mail_notice(access_ip)
  SessionMailer.notice(self, access_ip).deliver_later if locked?
end
```

**Impact on Future Extensibility**:
- **Switching email provider**: Requires changing mailer implementation
- **Adding SMS notifications**: Requires modifying brute force protection
- **Adding Slack notifications**: Requires modifying brute force protection
- **Multi-channel notifications**: Not supported

**Recommended Solution**:
```ruby
# app/services/notification_service.rb (NEW)
class NotificationService
  def send_account_locked(operator, context = {})
    raise NotImplementedError
  end
end

# app/services/email_notification_service.rb (NEW)
class EmailNotificationService < NotificationService
  def send_account_locked(operator, context = {})
    SessionMailer.notice(operator, context[:access_ip]).deliver_later
  end
end

# app/services/multi_channel_notification_service.rb (FUTURE)
class MultiChannelNotificationService < NotificationService
  def initialize(channels: [:email])
    @channels = channels
  end

  def send_account_locked(operator, context = {})
    @channels.each do |channel|
      case channel
      when :email
        EmailNotificationService.new.send_account_locked(operator, context)
      when :sms
        SmsNotificationService.new.send_account_locked(operator, context)
      when :slack
        SlackNotificationService.new.send_account_locked(operator, context)
      end
    end
  end
end

# app/models/concerns/brute_force_protection.rb (MODIFIED)
def mail_notice(access_ip)
  return unless locked?

  notification_service = NotificationServiceFactory.create
  notification_service.send_account_locked(self, access_ip: access_ip)
end
```

**Future Scenario - Adding SMS Notifications**:
```ruby
# Just implement the interface
class SmsNotificationService < NotificationService
  def send_account_locked(operator, context = {})
    TwilioClient.send_sms(
      to: operator.phone_number,
      body: "Your account has been locked due to multiple failed login attempts."
    )
  end
end

# Configure multi-channel
NotificationServiceFactory.channels = [:email, :sms]
```

**Current Effort to Add SMS**: **Medium** (modify brute force concern)
**With Abstraction**: **Low** (implement service interface)

---

#### 1.4 Missing SessionStore Abstraction

**Problem**: Session storage is hardcoded to Rails encrypted cookies (line 586-589).

**Current Implementation**:
```ruby
# app/controllers/concerns/authentication.rb
def login(operator)
  reset_session
  session[:operator_id] = operator.id  # HARDCODED: Cookie-based sessions
  @current_operator = operator
end
```

**Impact on Future Extensibility**:
- **Switching to Redis sessions**: Requires configuration changes
- **Database-backed sessions**: Requires migration
- **JWT tokens**: Not supported
- **Multi-device session management**: Difficult to implement

**Recommended Solution**:
```ruby
# app/services/session_store.rb (NEW)
class SessionStore
  def create_session(user)
    raise NotImplementedError
  end

  def destroy_session
    raise NotImplementedError
  end

  def current_user
    raise NotImplementedError
  end
end

# app/services/cookie_session_store.rb (NEW)
class CookieSessionStore < SessionStore
  def initialize(session)
    @session = session
  end

  def create_session(operator)
    @session[:operator_id] = operator.id
    operator
  end

  def destroy_session
    @session.delete(:operator_id)
  end

  def current_user
    return nil unless @session[:operator_id]
    @current_user ||= Operator.find_by(id: @session[:operator_id])
  end
end

# app/services/jwt_session_store.rb (FUTURE)
class JwtSessionStore < SessionStore
  def create_session(operator)
    JWT.encode({ operator_id: operator.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base)
  end

  def destroy_session
    # JWT is stateless, just return nil
    nil
  end

  def current_user
    token = request.headers['Authorization']&.split(' ')&.last
    payload = JWT.decode(token, Rails.application.secret_key_base).first
    Operator.find_by(id: payload['operator_id'])
  rescue JWT::DecodeError
    nil
  end
end

# app/controllers/concerns/authentication.rb (MODIFIED)
def login(operator)
  reset_session
  session_store.create_session(operator)
  @current_operator = operator
end

def current_operator
  @current_operator ||= session_store.current_user
end

private

def session_store
  @session_store ||= SessionStoreFactory.create(session)
end
```

**Future Scenario - Adding JWT Support**:
```ruby
# Configure factory
class SessionStoreFactory
  def self.create(session)
    strategy = ENV.fetch('SESSION_STRATEGY', 'cookie')
    case strategy
    when 'cookie' then CookieSessionStore.new(session)
    when 'jwt' then JwtSessionStore.new
    when 'redis' then RedisSessionStore.new
    end
  end
end

# No controller changes needed
```

**Current Effort to Add JWT**: **Very High** (extensive refactoring)
**With Abstraction**: **Low** (implement store interface)

---

**Strengths**:
1. ✅ BruteForceProtection extracted as concern (good separation)
2. ✅ Authentication concern provides consistent interface
3. ✅ Helper methods for session management

**Weaknesses**:
1. ❌ No provider abstraction (OAuth, SAML, LDAP not supported)
2. ❌ No hasher abstraction (switching algorithms difficult)
3. ❌ No notification abstraction (SMS, Slack not supported)
4. ❌ No session store abstraction (JWT, Redis difficult to add)

**Score Justification**:
- Base score: 3.0/10 (basic structure, no abstractions)
- +2.0 for BruteForceProtection concern extraction
- +0.0 for missing critical abstractions (4 major issues)
- **Total**: 5.0/10

---

### 2. Modularity: 7.0 / 10.0 (Weight: 30%)

**Findings**:
- ✅ **BruteForceProtection concern separated** - Clean responsibility
- ✅ **Authentication concern separated** - Good separation from controllers
- ✅ **SessionMailer separated** - Email logic isolated
- ✅ **Pundit integration unchanged** - Authorization independent
- ⚠️ **Authentication concern has multiple responsibilities** - Auth + session + brute force coordination
- ⚠️ **Password validation mixed with model** - Could be extracted

**Component Breakdown**:

| Component | File | Responsibility | Dependencies |
|-----------|------|----------------|--------------|
| 1. Authentication Concern | `app/controllers/concerns/authentication.rb` | Authenticate, session management | Operator, BruteForceProtection |
| 2. BruteForceProtection Concern | `app/models/concerns/brute_force_protection.rb` | Account locking logic | SessionMailer |
| 3. Operator Model | `app/models/operator.rb` | User data, password hashing | has_secure_password |
| 4. SessionsController | `app/controllers/operator/operator_sessions_controller.rb` | Login/logout actions | Authentication concern |
| 5. BaseController | `app/controllers/operator/base_controller.rb` | Auth requirement | Authentication concern |
| 6. SessionMailer | `app/mailers/session_mailer.rb` | Email notifications | None |
| 7. Pundit Policies | `app/policies/*.rb` | Authorization | Operator (unchanged) |

**Dependency Analysis**:
- **Mostly acyclic**: No circular dependencies
- **Some coupling**: Authentication concern depends on multiple components
- **Testable**: Components can be tested independently (mostly)

**Strengths**:
1. ✅ Clear separation between authentication and authorization (Pundit)
2. ✅ Brute force protection isolated as concern
3. ✅ Controllers thin, logic in concerns
4. ✅ Mailer separated from authentication logic
5. ✅ Model validations independent

**Weaknesses**:
1. ⚠️ Authentication concern coordinates too many responsibilities
2. ⚠️ Password policy hardcoded in model (could be service)
3. ⚠️ Session management mixed with authentication

**Recommended Improvements**:

**A. Extract SessionManager Service**:
```ruby
# app/services/session_manager.rb (NEW)
class SessionManager
  def initialize(session_store)
    @session_store = session_store
  end

  def create_session(operator)
    @session_store.create_session(operator)
  end

  def destroy_session
    @session_store.destroy_session
  end

  def current_user
    @session_store.current_user
  end
end

# app/controllers/concerns/authentication.rb (SIMPLIFIED)
def login(operator)
  reset_session
  session_manager.create_session(operator)
  @current_operator = operator
end

def logout
  session_manager.destroy_session
  @current_operator = nil
end

private

def session_manager
  @session_manager ||= SessionManager.new(session_store)
end
```

**B. Extract PasswordPolicy Service**:
```ruby
# app/services/password_policy.rb (NEW)
class PasswordPolicy
  def self.validate(password)
    errors = []
    errors << "too short (minimum 8 characters)" if password.length < 8
    errors << "must contain uppercase letter" unless password.match?(/[A-Z]/)
    errors << "must contain lowercase letter" unless password.match?(/[a-z]/)
    errors << "must contain number" unless password.match?(/[0-9]/)
    errors
  end

  def self.meets_requirements?(password)
    validate(password).empty?
  end
end

# app/models/operator.rb (SIMPLIFIED)
validates :password, length: { minimum: 8 }, if: -> { password.present? }
validate :password_meets_policy, if: -> { password.present? }

private

def password_meets_policy
  policy_errors = PasswordPolicy.validate(password)
  policy_errors.each { |error| errors.add(:password, error) }
end
```

**Future Scenario - Configurable Password Policy**:
```ruby
# config/initializers/password_policy.rb
PasswordPolicy.configure do |config|
  config.min_length = 10
  config.require_uppercase = true
  config.require_lowercase = true
  config.require_number = true
  config.require_special_char = true
  config.disallow_common_passwords = true
end
```

**Score Justification**:
- Base score: 8.0/10 (good separation)
- -0.5 for authentication concern doing too much
- -0.5 for missing service layer (session management, password policy)
- **Total**: 7.0/10

---

### 3. Future-Proofing: 6.0 / 10.0 (Weight: 20%)

**Findings**:
- ✅ **Migration strategy well-designed** - Dual password support, rollback plan
- ✅ **Feature flag mentioned** - Can switch between Sorcery and Rails 8
- ✅ **Database schema flexible** - Can add OAuth fields
- ❌ **No mention of MFA** - Multi-factor authentication not considered
- ❌ **No mention of social login** - OAuth, SAML not planned
- ❌ **No mention of passwordless** - Magic links, WebAuthn not considered
- ❌ **No session timeout** - Infinite sessions not secure
- ⚠️ **Brute force protection basic** - No rate limiting at application level

**Anticipated Future Scenarios**:

#### 3.1 Adding Multi-Factor Authentication (MFA) - NOT DESIGNED ❌

**Scenario**: Add TOTP (Google Authenticator) or SMS-based MFA

**Current Design Support**: **None**
- No database fields for MFA secrets
- No MFA verification flow in authentication concern
- No UI hooks for MFA setup

**Implementation Effort with Current Design**: **Very High**
```ruby
# Would require extensive changes:
# 1. Add mfa_secret, mfa_enabled to operators table
# 2. Modify authenticate_operator to check MFA
# 3. Add MFA setup controller
# 4. Add MFA verification controller
# 5. Modify session flow (store pending_mfa_operator_id)
```

**Recommended Design Addition**:
```ruby
# app/services/authentication/mfa_provider.rb (NEW)
module Authentication
  class MfaProvider
    def verify_totp(operator, code)
      totp = ROTP::TOTP.new(operator.mfa_secret)
      totp.verify(code, drift_behind: 30)
    end

    def verify_sms(operator, code)
      # SMS verification logic
    end
  end
end

# Migration needed:
add_column :operators, :mfa_enabled, :boolean, default: false
add_column :operators, :mfa_secret, :string
add_column :operators, :mfa_method, :string  # totp, sms, email

# Modified authentication flow:
def authenticate_operator(email, password, mfa_code: nil)
  operator = password_provider.authenticate(email, password)
  return nil unless operator

  if operator.mfa_enabled?
    return nil unless mfa_provider.verify(operator, mfa_code)
  end

  operator
end
```

**With Current Design**: Very High effort (3-5 days)
**With Abstraction**: Medium effort (1-2 days)

---

#### 3.2 Adding OAuth Social Login - NOT DESIGNED ❌

**Scenario**: Add Google, GitHub, Facebook login

**Current Design Support**: **Minimal**
- Password-only authentication assumed
- No OAuth provider abstraction
- No omniauth integration planned

**Implementation Effort with Current Design**: **Very High**
```ruby
# Would require:
# 1. Add oauth_provider, oauth_uid to operators table
# 2. Add omniauth gem and configuration
# 3. Create separate OAuthSessionsController
# 4. Modify Operator model to support OAuth users (no password)
# 5. Update authentication concern to handle OAuth
```

**Recommended Design Addition**:
```ruby
# With AuthenticationProvider abstraction (from Issue 1.1):
class OAuthProvider < Authentication::Provider
  def authenticate(provider:, token:)
    auth_hash = OmniAuth.auth_hash(provider, token)
    Operator.find_or_create_by(
      oauth_provider: provider,
      oauth_uid: auth_hash['uid']
    ) do |op|
      op.email = auth_hash['info']['email']
      op.name = auth_hash['info']['name']
      op.skip_password_validation = true
    end
  end
end

# Migration needed:
add_column :operators, :oauth_provider, :string
add_column :operators, :oauth_uid, :string
add_index :operators, [:oauth_provider, :oauth_uid], unique: true

# Make password optional for OAuth users:
validates :password, presence: true, unless: :oauth_user?

def oauth_user?
  oauth_provider.present?
end
```

**With Current Design**: Very High effort (4-6 days)
**With Abstraction**: Medium effort (2-3 days)

---

#### 3.3 Adding Passwordless Authentication - NOT DESIGNED ❌

**Scenario**: Add magic link or WebAuthn login

**Current Design Support**: **None**
- Password-centric design
- No token-based authentication
- No WebAuthn support

**Implementation Effort with Current Design**: **Very High**

**Recommended Design Addition**:
```ruby
# With AuthenticationProvider abstraction:
class MagicLinkProvider < Authentication::Provider
  def authenticate(token:)
    login_token = LoginToken.find_by(token: token, expires_at: Time.current..)
    return nil unless login_token

    login_token.operator.tap do
      login_token.destroy
    end
  end
end

# Migration needed:
create_table :login_tokens do |t|
  t.references :operator, foreign_key: true
  t.string :token, null: false, index: { unique: true }
  t.datetime :expires_at, null: false
  t.timestamps
end
```

**With Current Design**: Very High effort (5-7 days)
**With Abstraction**: Medium effort (2-3 days)

---

#### 3.4 Adding Session Timeout - PARTIALLY DESIGNED ⚠️

**Scenario**: Auto-logout after 30 minutes of inactivity

**Current Design Support**: **Partial** (session exists, but no timeout)

**Implementation Effort with Current Design**: **Medium**
```ruby
# Can add to Authentication concern:
def set_current_operator
  return unless session[:operator_id]

  # Check session timeout
  if session[:last_seen_at] && session[:last_seen_at] < 30.minutes.ago
    reset_session
    return nil
  end

  session[:last_seen_at] = Time.current
  @current_operator ||= Operator.find_by(id: session[:operator_id])
end
```

**With Current Design**: Medium effort (2-4 hours)
**With SessionStore Abstraction**: Low effort (1 hour)

---

#### 3.5 Adding Rate Limiting - MENTIONED BUT NOT DESIGNED ⚠️

**Scenario**: Rate limit login attempts per IP (not just per account)

**Current Design**: Mentioned as "Future Enhancement" (line 816) but not designed

**Implementation Effort with Current Design**: **Medium to High**
```ruby
# Would need:
# 1. Add Rack::Attack or similar gem
# 2. Configure rate limiting rules
# 3. Add Redis for distributed rate limiting
# 4. Handle rate limit errors in controller
```

**Recommended Design Addition**:
```ruby
# config/initializers/rack_attack.rb (NEW)
Rack::Attack.throttle('login attempts per IP', limit: 10, period: 5.minutes) do |req|
  req.ip if req.path == '/operator/cat_in' && req.post?
end

# app/controllers/operator/operator_sessions_controller.rb (MODIFIED)
rescue_from Rack::Attack::Throttle do
  flash.now[:alert] = 'ログイン試行回数が多すぎます。しばらくお待ちください。'
  render :new, status: :too_many_requests
end
```

**With Current Design**: Medium effort (1 day)
**With Design Addition**: Low effort (2-4 hours)

---

**Strengths**:
1. ✅ Migration strategy well-planned (dual password support)
2. ✅ Rollback capability designed
3. ✅ Feature flag support mentioned
4. ✅ Database schema allows OAuth fields addition

**Weaknesses**:
1. ❌ MFA not considered (critical for security)
2. ❌ Social login not designed (common requirement)
3. ❌ Passwordless not considered (emerging trend)
4. ⚠️ Session timeout not implemented (security gap)
5. ⚠️ Rate limiting mentioned but not designed

**Score Justification**:
- Base score: 5.0/10 (migration strategy good, future scenarios not considered)
- +1.0 for rollback plan and feature flag
- +0.5 for flexible database schema
- -0.5 for no MFA planning (critical)
- **Total**: 6.0/10

---

### 4. Configuration Points: 7.5 / 10.0 (Weight: 15%)

**Findings**:
- ✅ **Brute force thresholds configurable** - Via constants in concern
- ✅ **Password policy configurable** - Via model validations
- ✅ **Email format validation** - Via model validations
- ✅ **Bcrypt cost factor** - Mentioned (production: 12, test: 1)
- ⚠️ **Configuration in code, not ENV** - CONSECUTIVE_LOGIN_RETRIES_LIMIT hardcoded
- ⚠️ **Session timeout not configurable** - Not implemented
- ❌ **No feature flags for new auth methods** - No mechanism to enable/disable OAuth, MFA

**Configuration Points Identified**:

| Parameter | Current | Configurable? | Location |
|-----------|---------|---------------|----------|
| Consecutive login retry limit | 5 | ⚠️ Hardcoded constant | `BruteForceProtection::CONSECUTIVE_LOGIN_RETRIES_LIMIT` |
| Lock duration | 45 minutes | ⚠️ Hardcoded constant | `BruteForceProtection::LOGIN_LOCK_TIME_PERIOD` |
| Minimum password length | 8 | ⚠️ Hardcoded validation | `Operator` model |
| Password confirmation required | true | ❌ Not configurable | `Operator` model |
| Email format regex | `/\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/` | ❌ Hardcoded | `Operator` model |
| Bcrypt cost factor | 12 (prod), 1 (test) | ⚠️ Hardcoded | `has_secure_password` |
| Session duration | Browser session | ❌ Not configurable | Cookie settings |
| Feature flag (Sorcery vs Rails 8) | Mentioned | ✅ Via `Rails.configuration` | `authentication.rb` (line 1038) |

**Issues**:

#### 4.1 Brute Force Configuration Hardcoded

**Problem**: Lock threshold and duration are constants (lines 670-671).

**Current Implementation**:
```ruby
# app/models/concerns/brute_force_protection.rb
CONSECUTIVE_LOGIN_RETRIES_LIMIT = 5
LOGIN_LOCK_TIME_PERIOD = 45.minutes
```

**Recommended Solution**:
```ruby
# config/initializers/brute_force_protection.rb (NEW)
Rails.application.config.brute_force_protection = {
  consecutive_login_retries_limit: ENV.fetch('LOGIN_RETRY_LIMIT', 5).to_i,
  login_lock_time_period: ENV.fetch('LOGIN_LOCK_DURATION', 45).to_i.minutes
}

# app/models/concerns/brute_force_protection.rb (MODIFIED)
def consecutive_login_retries_limit
  Rails.configuration.brute_force_protection[:consecutive_login_retries_limit]
end

def login_lock_time_period
  Rails.configuration.brute_force_protection[:login_lock_time_period]
end
```

**Benefit**: Can adjust security parameters without code deployment

---

#### 4.2 Password Policy Hardcoded

**Problem**: Password rules hardcoded in model validations (line 649).

**Current Implementation**:
```ruby
# app/models/operator.rb
validates :password, length: { minimum: 8 }, if: -> { password.present? }
```

**Recommended Solution**:
```ruby
# config/initializers/password_policy.rb (NEW)
Rails.application.config.password_policy = {
  min_length: ENV.fetch('PASSWORD_MIN_LENGTH', 8).to_i,
  require_uppercase: ENV.fetch('PASSWORD_REQUIRE_UPPERCASE', 'false') == 'true',
  require_lowercase: ENV.fetch('PASSWORD_REQUIRE_LOWERCASE', 'false') == 'true',
  require_number: ENV.fetch('PASSWORD_REQUIRE_NUMBER', 'false') == 'true',
  require_special_char: ENV.fetch('PASSWORD_REQUIRE_SPECIAL', 'false') == 'true'
}

# app/models/operator.rb (MODIFIED)
validates :password, length: { minimum: Rails.configuration.password_policy[:min_length] }, if: -> { password.present? }
validate :password_complexity, if: -> { password.present? }

private

def password_complexity
  policy = Rails.configuration.password_policy
  errors.add(:password, 'must contain uppercase letter') if policy[:require_uppercase] && !password.match?(/[A-Z]/)
  errors.add(:password, 'must contain lowercase letter') if policy[:require_lowercase] && !password.match?(/[a-z]/)
  errors.add(:password, 'must contain number') if policy[:require_number] && !password.match?(/[0-9]/)
  errors.add(:password, 'must contain special character') if policy[:require_special_char] && !password.match?(/[^A-Za-z0-9]/)
end
```

**Benefit**: Can strengthen password policy without code changes

---

#### 4.3 No Feature Flags for Authentication Methods

**Problem**: No way to enable/disable new authentication methods.

**Recommended Solution**:
```ruby
# config/initializers/authentication_methods.rb (NEW)
Rails.application.config.authentication_methods = {
  password: ENV.fetch('AUTH_PASSWORD_ENABLED', 'true') == 'true',
  oauth: ENV.fetch('AUTH_OAUTH_ENABLED', 'false') == 'true',
  mfa: ENV.fetch('AUTH_MFA_ENABLED', 'false') == 'true',
  passwordless: ENV.fetch('AUTH_PASSWORDLESS_ENABLED', 'false') == 'true'
}

# app/controllers/concerns/authentication.rb (MODIFIED)
def authenticate_operator(method, **credentials)
  unless authentication_method_enabled?(method)
    raise AuthenticationMethodDisabledError
  end

  provider = AuthenticationProviderFactory.create(method)
  provider.authenticate(**credentials)
end

private

def authentication_method_enabled?(method)
  Rails.configuration.authentication_methods[method]
end
```

**Benefit**: Gradual rollout of new authentication methods, instant rollback

---

#### 4.4 Session Configuration Missing

**Problem**: Session duration not configurable (line 833: "Browser session").

**Recommended Solution**:
```ruby
# config/initializers/session_store.rb (MODIFIED)
Rails.application.config.session_store :cookie_store,
  key: '_cat_salvages_session',
  expire_after: ENV.fetch('SESSION_TIMEOUT', 24.hours.to_i).to_i.seconds,
  httponly: true,
  secure: Rails.env.production?,
  same_site: :lax

# Add session timeout in Authentication concern:
def session_expired?
  return false unless session[:last_seen_at]
  session[:last_seen_at] < session_timeout.ago
end

def session_timeout
  ENV.fetch('SESSION_TIMEOUT', 30.minutes.to_i).to_i.seconds
end
```

**Benefit**: Can adjust session duration for compliance requirements

---

**Strengths**:
1. ✅ Key security parameters identified (retry limit, lock duration)
2. ✅ Password policy clear
3. ✅ Feature flag for migration mentioned
4. ✅ Bcrypt cost factor configurable (environment-based)

**Weaknesses**:
1. ⚠️ Configuration in code constants, not ENV variables
2. ⚠️ No feature flags for new authentication methods
3. ❌ Session timeout not configurable
4. ❌ Password policy not flexible

**Score Justification**:
- Base score: 6.0/10 (configuration exists but hardcoded)
- +1.5 for clear security parameters and feature flag
- +0.0 for lack of ENV-based configuration
- **Total**: 7.5/10

---

## Summary of Critical Issues

### Issue 1: Missing AuthenticationProvider Abstraction ❌ HIGH PRIORITY

**Status**: Not Designed

**Impact**:
- Cannot add OAuth without extensive refactoring
- Cannot add SAML without extensive refactoring
- Cannot add MFA without extensive refactoring
- Cannot add passwordless authentication

**Recommendation**: Implement `Authentication::Provider` interface pattern (see Section 1.1)

**Effort to Implement**: Medium (1-2 days)
**Effort Without Abstraction**: Very High (4-6 days per new method)

---

### Issue 2: Missing PasswordHasher Abstraction ❌ MEDIUM PRIORITY

**Status**: Not Designed

**Impact**:
- Cannot switch to Argon2 without replacing `has_secure_password`
- Cannot support multiple hash algorithms during migration
- Cannot customize password hashing behavior

**Recommendation**: Implement `PasswordHasher` interface pattern (see Section 1.2)

**Effort to Implement**: Medium (1 day)
**Effort Without Abstraction**: High (2-3 days to switch algorithms)

---

### Issue 3: No MFA Planning ❌ HIGH PRIORITY (SECURITY)

**Status**: Not Considered

**Impact**:
- Security gap for high-value accounts
- Compliance risk (many regulations require MFA)
- Adding MFA later requires extensive refactoring

**Recommendation**: Add MFA fields to database schema, design MFA flow (see Section 3.1)

**Effort to Add Now**: Low (1 day design + 2 days implementation)
**Effort to Add Later**: Very High (5-7 days)

---

### Issue 4: No OAuth/Social Login Planning ❌ MEDIUM PRIORITY

**Status**: Not Considered

**Impact**:
- Cannot add Google/GitHub/Facebook login without refactoring
- User convenience gap
- Competitive disadvantage

**Recommendation**: Design OAuth integration with provider abstraction (see Section 3.2)

**Effort to Add Now**: Medium (2-3 days with abstraction)
**Effort to Add Later**: Very High (6-8 days without abstraction)

---

### Issue 5: Configuration Hardcoded in Code ⚠️ MEDIUM PRIORITY

**Status**: Partially Designed

**Impact**:
- Cannot change security parameters without deployment
- Cannot A/B test different password policies
- Cannot adjust session timeout for compliance

**Recommendation**: Move configuration to ENV variables (see Section 4)

**Effort to Implement**: Low (4-6 hours)

---

## Action Items for Designer

**To achieve "Approved" status (≥ 7.0/10), please address:**

### Required Changes (Must Address):

1. **Design AuthenticationProvider abstraction** (Section 1.1):
   - Add `Authentication::Provider` interface
   - Implement `PasswordProvider` as first provider
   - Design factory pattern for provider selection
   - Document how to add OAuth, SAML, MFA providers

2. **Add MFA planning to design** (Section 3.1):
   - Add database fields for MFA (mfa_enabled, mfa_secret, mfa_method)
   - Design MFA verification flow
   - Document TOTP, SMS, email MFA options
   - Add to "Future Extensions" section

3. **Add configuration section** (Section 4):
   - List all configurable parameters in table
   - Specify ENV variable names
   - Provide default values
   - Document feature flags for auth methods

### Recommended Changes (Should Address):

4. **Design OAuth integration** (Section 3.2):
   - Add database fields for OAuth (oauth_provider, oauth_uid)
   - Design OAuth provider implementation
   - Document omniauth integration
   - Make password optional for OAuth users

5. **Extract SessionStore abstraction** (Section 1.4):
   - Design `SessionStore` interface
   - Implement `CookieSessionStore`
   - Document how to add JWT, Redis sessions

6. **Add session timeout** (Section 3.4):
   - Design session expiry logic
   - Add configurable timeout parameter
   - Document auto-logout behavior

### Optional Enhancements (Nice to Have):

7. **Design PasswordHasher abstraction** (Section 1.2):
   - For future Argon2 migration
   - Lower priority than provider abstraction

8. **Design NotificationService abstraction** (Section 1.3):
   - For future SMS, Slack notifications
   - Lower priority than MFA

---

## Future Extensibility Scenarios (After Improvements)

### Scenario 1: Add Google OAuth Login

**With Current Design**: **Very High Effort** (6-8 days)
**With Recommended Changes**: **Medium Effort** (2-3 days)

```ruby
# Just implement the provider interface
class GoogleOAuthProvider < Authentication::Provider
  def authenticate(id_token:)
    # Google OAuth implementation
  end
end

# Enable via feature flag
export AUTH_OAUTH_ENABLED=true
```

---

### Scenario 2: Add TOTP Multi-Factor Authentication

**With Current Design**: **Very High Effort** (5-7 days)
**With Recommended Changes**: **Medium Effort** (2-3 days)

```ruby
# Just implement the provider interface
class MfaProvider < Authentication::Provider
  def verify(operator, totp_code)
    # TOTP verification
  end
end

# Enable via feature flag
export AUTH_MFA_ENABLED=true
```

---

### Scenario 3: Switch to Argon2 Password Hashing

**With Current Design**: **Very High Effort** (3-5 days)
**With Recommended Changes**: **Low Effort** (1 day)

```ruby
# Implement hasher interface
class Argon2Hasher < PasswordHasher
  def hash(password)
    Argon2::Password.create(password)
  end
end

# Configure factory
export PASSWORD_ALGORITHM=argon2
```

---

### Scenario 4: Add SMS Notifications for Locked Accounts

**With Current Design**: **Medium Effort** (1-2 days)
**With Recommended Changes**: **Low Effort** (4-6 hours)

```ruby
# Implement notification service
class SmsNotificationService < NotificationService
  def send_account_locked(operator, context)
    # Twilio SMS implementation
  end
end

# Configure multi-channel
NotificationServiceFactory.channels = [:email, :sms]
```

---

## Strengths

1. ✅ **Excellent migration strategy** - Dual password support, rollback plan
2. ✅ **Comprehensive brute force protection** - Account locking, email notifications
3. ✅ **Clean separation of concerns** - Authentication, authorization, models separated
4. ✅ **Good test coverage planned** - Unit, integration, system tests
5. ✅ **Security-focused** - bcrypt, session reset, CSRF protection
6. ✅ **Data migration well-planned** - Checksum validation, rollback capability
7. ✅ **Japanese UI preserved** - Custom messages maintained

---

## Weaknesses

1. ❌ **No abstraction for authentication providers** - Cannot add OAuth, SAML easily
2. ❌ **No MFA planning** - Critical security gap
3. ❌ **No OAuth planning** - Common requirement not addressed
4. ⚠️ **Configuration hardcoded** - Should use ENV variables
5. ❌ **No session timeout** - Security risk
6. ⚠️ **Authentication concern too broad** - Multiple responsibilities

---

## Structured Data

```yaml
evaluation_result:
  evaluator: "design-extensibility-evaluator"
  design_document: "docs/designs/rails8-authentication-migration.md"
  timestamp: "2025-11-24T10:30:00+09:00"
  feature_id: "FEAT-AUTH-001"

  overall_judgment:
    status: "Request Changes"
    overall_score: 6.5
    summary: "Solid foundation but lacks critical abstractions for future authentication methods"

  detailed_scores:
    interface_design:
      score: 5.0
      weight: 0.35
      weighted_score: 1.75
      key_issues:
        - "Missing AuthenticationProvider abstraction"
        - "Missing PasswordHasher abstraction"
        - "Missing EmailService abstraction"
        - "Missing SessionStore abstraction"

    modularity:
      score: 7.0
      weight: 0.30
      weighted_score: 2.10
      key_issues:
        - "Authentication concern has multiple responsibilities"
        - "Password policy could be extracted to service"

    future_proofing:
      score: 6.0
      weight: 0.20
      weighted_score: 1.20
      key_issues:
        - "MFA not considered"
        - "OAuth not planned"
        - "Passwordless not considered"
        - "Session timeout not implemented"

    configuration_points:
      score: 7.5
      weight: 0.15
      weighted_score: 1.125
      key_issues:
        - "Configuration hardcoded in constants"
        - "No feature flags for auth methods"
        - "Session timeout not configurable"

  total_weighted_score: 6.175  # Rounded to 6.5

  critical_issues:
    - issue: "Missing AuthenticationProvider abstraction"
      severity: "high"
      category: "interface_design"
      impact: "Cannot add OAuth, SAML, MFA without extensive refactoring"
      effort_to_fix: "Medium (1-2 days)"
      effort_without_fix: "Very High (4-6 days per new auth method)"

    - issue: "No MFA planning"
      severity: "high"
      category: "future_proofing"
      impact: "Security gap, compliance risk, expensive to add later"
      effort_to_fix: "Low (1 day design + 2 days implementation)"
      effort_without_fix: "Very High (5-7 days)"

    - issue: "No OAuth/Social login planning"
      severity: "medium"
      category: "future_proofing"
      impact: "Cannot add Google/GitHub login easily"
      effort_to_fix: "Medium (2-3 days with abstraction)"
      effort_without_fix: "Very High (6-8 days)"

    - issue: "Configuration hardcoded in code"
      severity: "medium"
      category: "configuration_points"
      impact: "Cannot change security parameters without deployment"
      effort_to_fix: "Low (4-6 hours)"

    - issue: "No session timeout"
      severity: "medium"
      category: "future_proofing"
      impact: "Security risk, compliance issue"
      effort_to_fix: "Low (2-4 hours)"

  required_changes:
    - change: "Design AuthenticationProvider abstraction"
      section: "3.3 Component Architecture"
      details: "Add Provider interface, PasswordProvider, factory pattern"

    - change: "Add MFA planning"
      section: "2.2 Functional Requirements, 3.1 Architecture"
      details: "Add database fields, design MFA flow, document options"

    - change: "Add configuration section"
      section: "New section 9"
      details: "List ENV variables, defaults, feature flags"

  recommended_changes:
    - change: "Design OAuth integration"
      section: "3.3 Component Architecture"
      details: "Add OAuth provider, database fields, omniauth integration"

    - change: "Extract SessionStore abstraction"
      section: "3.3 Component Architecture"
      details: "Add SessionStore interface, document JWT/Redis options"

    - change: "Add session timeout"
      section: "6 Security Considerations"
      details: "Design session expiry logic, configurable timeout"

  future_scenarios:
    - scenario: "Add Google OAuth login"
      current_effort: "Very High (6-8 days)"
      with_abstraction: "Medium (2-3 days)"
      blocker: "Missing AuthenticationProvider abstraction"

    - scenario: "Add TOTP MFA"
      current_effort: "Very High (5-7 days)"
      with_abstraction: "Medium (2-3 days)"
      blocker: "No MFA planning, missing provider abstraction"

    - scenario: "Switch to Argon2"
      current_effort: "Very High (3-5 days)"
      with_abstraction: "Low (1 day)"
      blocker: "Missing PasswordHasher abstraction"

    - scenario: "Add SMS notifications"
      current_effort: "Medium (1-2 days)"
      with_abstraction: "Low (4-6 hours)"
      blocker: "Missing NotificationService abstraction"

    - scenario: "Add session timeout"
      current_effort: "Medium (2-4 hours)"
      with_abstraction: "Low (1 hour)"
      blocker: "No session timeout design"

  strengths:
    - "Excellent migration strategy with rollback plan"
    - "Comprehensive brute force protection"
    - "Clean separation between authentication and authorization"
    - "Good test coverage planned"
    - "Security-focused design (bcrypt, session reset, CSRF)"
    - "Data migration well-planned with checksums"
    - "Japanese UI preserved"
    - "BruteForceProtection extracted as concern"

  weaknesses:
    - "No abstraction for authentication providers"
    - "No MFA planning (security gap)"
    - "No OAuth planning (common requirement)"
    - "Configuration hardcoded in constants"
    - "No session timeout (security risk)"
    - "Authentication concern too broad"
    - "No passwordless authentication considered"

  approval_threshold: 7.0
  current_score: 6.5
  gap: 0.5

  estimated_effort_to_approve:
    required_changes: "3-4 days"
    recommended_changes: "2-3 days"
    total: "5-7 days"
```

---

## Conclusion

**The design receives a score of 6.5/10 and requires changes before approval.**

**Key Gaps**:
1. ❌ Missing AuthenticationProvider abstraction (blocks OAuth, SAML, MFA)
2. ❌ No MFA planning (critical security gap)
3. ❌ No OAuth planning (common user requirement)
4. ⚠️ Configuration hardcoded (limits flexibility)
5. ⚠️ No session timeout (security risk)

**Path to Approval (≥ 7.0)**:
1. Add AuthenticationProvider abstraction design (+1.0 point)
2. Add MFA planning with database fields (+0.5 point)
3. Move configuration to ENV variables (+0.3 point)
4. Add session timeout design (+0.2 point)

**Estimated Effort**: 3-4 days for required changes

**Recommendation**: **Request Changes**

The current design handles the Sorcery to Rails 8 migration excellently, but does not adequately prepare for future authentication enhancements. Adding the recommended abstractions now will prevent expensive refactoring later when OAuth, MFA, or other authentication methods are needed.

---

**Evaluation Complete - 2025-11-24T10:30:00+09:00**
