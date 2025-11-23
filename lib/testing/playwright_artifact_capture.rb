# frozen_string_literal: true

require 'tempfile'
require_relative 'utils/time_utils'
require_relative 'utils/string_utils'
require_relative 'utils/null_logger'

module Testing
  # Service for capturing Playwright artifacts (screenshots and traces).
  #
  # Handles screenshot and trace capture on test failures with correlation IDs
  # and metadata support. Works with any browser driver and storage backend.
  #
  # @example Basic usage
  #   driver = PlaywrightDriver.new
  #   storage = FileSystemStorage.new
  #   capture = PlaywrightArtifactCapture.new(driver: driver, storage: storage)
  #
  #   # Capture screenshot on failure
  #   capture.capture_screenshot(page, test_name: 'User login spec', metadata: {
  #     example_id: './spec/system/users_spec.rb[1:2:1]'
  #   })
  #
  # @example With custom logger
  #   capture = PlaywrightArtifactCapture.new(
  #     driver: driver,
  #     storage: storage,
  #     logger: Rails.logger
  #   )
  #
  # @since 1.0.0
  class PlaywrightArtifactCapture
    # @return [BrowserDriver] Browser driver instance
    attr_reader :driver

    # @return [ArtifactStorage] Storage backend instance
    attr_reader :storage

    # @return [Logger] Logger instance
    attr_reader :logger

    # Initialize artifact capture service.
    #
    # @param driver [BrowserDriver] Browser driver for screenshot/trace capture
    # @param storage [ArtifactStorage] Storage backend for saving artifacts
    # @param logger [Logger] Logger for structured output (default: NullLogger)
    def initialize(driver:, storage:, logger: Utils::NullLogger.new)
      @driver = driver
      @storage = storage
      @logger = logger
    end

    # Capture screenshot on test failure.
    #
    # Generates unique artifact name with correlation ID, captures screenshot,
    # and saves to storage with metadata.
    #
    # @param page [Playwright::Page] Playwright page object
    # @param test_name [String] Test name for artifact naming
    # @param metadata [Hash] Additional metadata (example_id, file location, etc.)
    # @return [Pathname, nil] Path to saved screenshot or nil if capture failed
    #
    # @example
    #   path = capture.capture_screenshot(page, test_name: 'User login spec', metadata: {
    #     example_id: './spec/system/users_spec.rb[1:2:1]',
    #     file_location: './spec/system/users_spec.rb:42'
    #   })
    def capture_screenshot(page, test_name:, metadata: {})
      artifact_name = generate_artifact_name(test_name)
      temp_file = Tempfile.new(['screenshot', '.png'])

      begin
        driver.take_screenshot(page, temp_file.path)
        enhanced_metadata = metadata.merge(
          test_name: test_name,
          timestamp: Utils::TimeUtils.format_iso8601,
          correlation_id: artifact_name
        )

        saved_path = storage.save_screenshot(artifact_name, temp_file.path, enhanced_metadata)
        log_artifact_saved('screenshot', saved_path, enhanced_metadata)

        saved_path
      rescue StandardError => e
        logger.error("Failed to capture screenshot: #{e.message}")
        nil
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    # Capture trace with configurable mode.
    #
    # Starts trace, executes block, stops trace and saves to storage.
    # Trace mode controls when traces are captured:
    # - 'on': Always capture traces
    # - 'off': Never capture traces
    # - 'on-first-retry': Capture traces on first retry attempt
    #
    # @param context [Playwright::BrowserContext] Playwright browser context
    # @param test_name [String] Test name for artifact naming
    # @param trace_mode [String] Trace capture mode ('on', 'off', 'on-first-retry')
    # @param metadata [Hash] Additional metadata
    # @yield Block to execute with tracing enabled
    # @return [Pathname, nil] Path to saved trace or nil if not captured
    #
    # @example
    #   path = capture.capture_trace(context, test_name: 'User login spec', trace_mode: 'on') do
    #     page.goto('http://localhost:3000')
    #     page.click('text=Login')
    #   end
    def capture_trace(context, test_name:, trace_mode:, metadata: {}, &block)
      return yield if trace_mode == 'off'

      artifact_name = generate_artifact_name(test_name)
      temp_file = Tempfile.new(['trace', '.zip'])

      begin
        result = execute_trace_capture(context, temp_file.path, &block)
        save_trace_artifact(artifact_name, temp_file.path, test_name, trace_mode, metadata)
        result
      rescue StandardError => e
        logger.error("Failed to capture trace: #{e.message}")
        raise
      ensure
        cleanup_temp_file(temp_file)
      end
    end

    private

    # Generate unique artifact name with correlation ID.
    #
    # @param test_name [String] Test name
    # @return [String] Sanitized artifact name with correlation ID
    def generate_artifact_name(test_name)
      correlation_id = Utils::TimeUtils.generate_correlation_id('test')
      sanitized_test_name = Utils::StringUtils.sanitize_filename(test_name)

      "#{sanitized_test_name}-#{correlation_id}"
    end

    # Log artifact saved with structured output.
    #
    # @param type [String] Artifact type ('screenshot' or 'trace')
    # @param path [Pathname] Path to saved artifact
    # @param metadata [Hash] Artifact metadata
    # @return [void]
    def log_artifact_saved(type, path, metadata)
      logger.info("Artifact saved: #{type} | path=#{path} | correlation_id=#{metadata[:correlation_id]}")
    end

    # Execute trace capture with Playwright.
    #
    # @param context [Playwright::BrowserContext] Browser context
    # @param temp_path [String] Temporary file path for trace
    # @yield Block to execute with tracing
    # @return [Object] Result from block execution
    def execute_trace_capture(context, temp_path)
      driver.start_trace(context)
      result = yield
      driver.stop_trace(context, temp_path)
      result
    end

    # Save trace artifact with metadata.
    #
    # @param artifact_name [String] Artifact name
    # @param temp_path [String] Temporary file path
    # @param test_name [String] Test name
    # @param trace_mode [String] Trace mode
    # @param metadata [Hash] Additional metadata
    # @return [Pathname] Path to saved trace
    def save_trace_artifact(artifact_name, temp_path, test_name, trace_mode, metadata)
      enhanced_metadata = metadata.merge(
        test_name: test_name,
        timestamp: Utils::TimeUtils.format_iso8601,
        correlation_id: artifact_name,
        trace_mode: trace_mode
      )

      saved_path = storage.save_trace(artifact_name, temp_path, enhanced_metadata)
      log_artifact_saved('trace', saved_path, enhanced_metadata)
      saved_path
    end

    # Cleanup temporary file.
    #
    # @param temp_file [Tempfile] Temporary file to cleanup
    # @return [void]
    def cleanup_temp_file(temp_file)
      temp_file.close
      temp_file.unlink
    end
  end
end
