# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/all'

# OpenTelemetry Configuration
#
# Configures distributed tracing for the application using OpenTelemetry.
# Automatically instruments Rails, ActiveRecord, and other common libraries.

# Only enable in production or if explicitly requested
if Rails.env.production? || ENV['OTEL_ENABLED'] == 'true'
  OpenTelemetry::SDK.configure do |c|
    # Service name for identification in traces
    c.service_name = ENV.fetch('OTEL_SERVICE_NAME', 'cat-salvages-the-relationship')
    c.service_version = ENV.fetch('APP_VERSION', '2.0.0')

    # Configure resource attributes
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      'service.name' => ENV.fetch('OTEL_SERVICE_NAME', 'cat-salvages-the-relationship'),
      'service.version' => ENV.fetch('APP_VERSION', '2.0.0'),
      'deployment.environment' => Rails.env,
      'host.name' => ENV.fetch('HOSTNAME', Socket.gethostname)
    )

    # Enable all automatic instrumentation
    c.use_all(
      'OpenTelemetry::Instrumentation::ActiveRecord' => {
        # Enable SQL query capturing (be careful with sensitive data)
        enable_sql_obfuscation: true,
        # Add span attributes
        db_statement: :include
      },
      'OpenTelemetry::Instrumentation::ActionPack' => {
        # Capture request/response attributes
        enable_recognize_route: true
      },
      'OpenTelemetry::Instrumentation::ActiveSupport' => {
        # Capture cache operations
        enable_cache_store: true
      },
      'OpenTelemetry::Instrumentation::Rails' => {
        # Capture Rails-specific attributes
        enable_recognize_route: true
      }
    )

    # Configure exporter based on environment
    if ENV['OTEL_EXPORTER_OTLP_ENDPOINT']
      # Export to OpenTelemetry Collector (recommended for production)
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(
            endpoint: ENV['OTEL_EXPORTER_OTLP_ENDPOINT'],
            headers: {
              'Authorization' => ENV['OTEL_EXPORTER_OTLP_HEADERS']
            }.compact
          )
        )
      )
    elsif Rails.env.development?
      # Development: Log spans to console
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
          OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter.new
        )
      )
    end

    # Configure sampling strategy
    # In production, you may want to sample only a percentage of requests
    sample_rate = ENV.fetch('OTEL_TRACE_SAMPLE_RATE', '1.0').to_f
    c.sampler = if sample_rate >= 1.0
                  OpenTelemetry::SDK::Trace::Samplers::ALWAYS_ON
                elsif sample_rate <= 0.0
                  OpenTelemetry::SDK::Trace::Samplers::ALWAYS_OFF
                else
                  OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(sample_rate)
                end
  end

  Rails.logger.info 'OpenTelemetry tracing enabled'
  Rails.logger.info "  Service: #{ENV.fetch('OTEL_SERVICE_NAME', 'cat-salvages-the-relationship')}"
  Rails.logger.info "  Environment: #{Rails.env}"
  Rails.logger.info "  Sample rate: #{ENV.fetch('OTEL_TRACE_SAMPLE_RATE', '1.0')}"
else
  Rails.logger.info 'OpenTelemetry tracing disabled (set OTEL_ENABLED=true to enable in development)'
end
