# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - LINE Bot SDK Modernization (2025-11-17)

#### New Features
- **Health Check Endpoints**:
  - `GET /health` - Shallow health check for load balancers
  - `GET /health/deep` - Deep health check verifying database and LINE credentials
- **Prometheus Metrics**: `GET /metrics` endpoint for monitoring
  - Webhook processing duration and success rate
  - LINE API call metrics
  - Group count gauge
  - Message send counters
- **Structured Logging**: JSON-formatted logs with correlation IDs via Lograge
- **Error Sanitization**: Automatic removal of sensitive data from error messages

#### Architecture Improvements
- **Service-Oriented Architecture**: Replaced monolithic `CatLineBot` with focused services:
  - `Line::EventProcessor` - Core webhook orchestration
  - `Line::GroupService` - Group lifecycle management
  - `Line::CommandHandler` - Special command processing
  - `Line::OneOnOneHandler` - 1-on-1 chat handling
- **Client Abstraction**: `Line::ClientAdapter` interface for SDK isolation
- **Reusable Utilities**:
  - `Webhooks::SignatureValidator` - Webhook signature verification
  - `Resilience::RetryHandler` - Exponential backoff retry logic
  - `ErrorHandling::MessageSanitizer` - Credential leak prevention
  - `Line::MemberCounter` - Member counting with graceful degradation
  - `PrometheusMetrics` - Centralized metrics tracking

#### Reliability Enhancements
- **8-second Timeout Protection**: Prevents webhook processing from exceeding LINE's limits
- **Transaction Management**: Atomic operations for data consistency
- **Idempotency Tracking**: Prevents duplicate processing of webhooks
- **Retry Logic**: Exponential backoff for transient failures (max 3 attempts)
- **Graceful Degradation**: Member count fallback (default: 2)

#### Security Improvements
- **Timing Attack Prevention**: Secure signature comparison via `ActiveSupport::SecurityUtils`
- **Credential Protection**: MessageSanitizer removes sensitive data from logs
- **Error Message Safety**: Sanitized error notifications prevent information leakage

#### Developer Experience
- **Dependency Injection**: All services accept dependencies for easy testing
- **Comprehensive Documentation**: YARD docs for all classes and methods
- **Test Helpers**: Reusable test utilities in `spec/support/`
- **100% Backward Compatible**: No breaking changes to existing functionality

### Changed

#### Updated Dependencies
- `line-bot-api`: Updated to `~> 2.0` (from implicit v1.x)
- Added `prometheus-client ~> 4.0` for metrics collection
- Added `lograge ~> 0.14` for structured logging
- Added `request_store ~> 1.5` for request-scoped storage

#### Modified Files
- `app/controllers/operator/webhooks_controller.rb`:
  - Now uses `Line::EventProcessor` instead of `CatLineBot`
  - Integrated `Webhooks::SignatureValidator`
  - Added timeout protection and error handling
  - Returns appropriate HTTP status codes (200, 400, 503)
- `app/models/scheduler.rb`:
  - Migrated to `Line::ClientProvider`
  - Added `Resilience::RetryHandler` for reliability
  - Improved transaction safety
  - Enhanced error logging with sanitization
- `config/routes.rb`:
  - Added `/health` and `/health/deep` routes
  - Added `/metrics` route

#### New Configuration Files
- `config/initializers/lograge.rb` - Structured logging configuration
- `config/initializers/prometheus.rb` - Metrics definitions (7 metrics)
- `config/environments/production.rb` - Log rotation (10 files, 100MB)

### Removed

- `app/models/cat_line_bot.rb` (89 lines) - Replaced by service architecture
- `app/models/concerns/message_event.rb` (60 lines) - Logic moved to handlers

### Technical Details

#### Code Quality
- **RuboCop Clean**: 0 blocking violations
- **Test Coverage**: 88.06% (target: ≥90%)
- **Created Files**: 18 new files
- **Deleted Files**: 2 legacy files
- **Net Code Change**: +600 lines (149 deleted, 600+ added)

#### Performance Impact
- **Webhook Processing**: No regression, improved error handling
- **Memory Usage**: Slightly increased due to new services (acceptable)
- **Cold Start**: +50ms for additional service initialization

### Migration Notes

- **Zero Downtime**: Deployment can be done without service interruption
- **No Database Changes**: Existing schema remains unchanged
- **Credential Migration**: Not required - same structure
- **Rollback**: Simple git revert, no data migration needed

See [MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md) for detailed migration instructions.

---

## Previous Releases

(Add previous release notes here)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
