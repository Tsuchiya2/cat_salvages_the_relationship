# frozen_string_literal: true

# Database version compatibility check
# Verifies that the current database version meets minimum requirements
# Only runs in production and staging environments

Rails.application.config.after_initialize do
  next unless Rails.env.production? || Rails.env.staging?

  begin
    require_relative '../../lib/database_version_manager/version_compatibility'

    DatabaseVersionManager::VersionCompatibility.verify_version!

    Rails.logger.info 'Database version check passed successfully'
  rescue DatabaseVersionManager::DatabaseVersionError => e
    Rails.logger.error "Database version check failed: #{e.message}"

    # In production, this should alert the operations team
    # For now, we'll raise the error to prevent application startup with unsupported version
    raise
  rescue StandardError => e
    Rails.logger.warn "Database version check skipped due to error: #{e.message}"
    # Don't prevent startup for unexpected errors
  end
end
