# frozen_string_literal: true

require 'semantic_logger'

# Configure SemanticLogger with JSON format
SemanticLogger.application = 'CatSalvagesTheRelationship'

# Set log level from environment or default to info
SemanticLogger.default_level = ENV.fetch('LOG_LEVEL', 'info').to_sym

# Configure appenders
if Rails.env.production?
  # Production: Log to STDOUT and file with JSON format
  SemanticLogger.add_appender(io: $stdout, formatter: :json)
  SemanticLogger.add_appender(
    file_name: Rails.root.join('log', 'production.log'),
    formatter: :json
  )
else
  # Development/Test: Log to STDOUT with color format for readability
  SemanticLogger.add_appender(io: $stdout, formatter: :color)
  log_file = Rails.root.join('log', "#{Rails.env}.log").to_s
  if log_file.present? && !log_file.end_with?('.log')
    log_file = Rails.root.join('log', 'development.log').to_s
  end
  SemanticLogger.add_appender(
    file_name: log_file,
    formatter: :json
  )
end

# Replace Rails logger with SemanticLogger
Rails.application.config.logger = SemanticLogger[Rails]

# Configure ActiveRecord to use SemanticLogger
ActiveRecord::Base.logger = SemanticLogger[ActiveRecord]
