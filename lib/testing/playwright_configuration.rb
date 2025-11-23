# frozen_string_literal: true

require_relative 'utils/path_utils'
require_relative 'utils/env_utils'
require 'fileutils'

module Testing
  # Centralized Playwright configuration with environment-specific settings.
  #
  # Provides environment-specific presets (CI, local, development) and allows
  # customization via environment variables. Uses PathUtils and EnvUtils for
  # framework-agnostic operation (no Rails dependencies).
  #
  # @example Basic usage (auto-detect environment)
  #   config = PlaywrightConfiguration.for_environment
  #   config.headless #=> true (in CI)
  #   config.browser_type #=> "chromium"
  #
  # @example CI configuration
  #   config = PlaywrightConfiguration.ci_config
  #   config.headless #=> true
  #   config.timeout #=> 60000
  #   config.trace_mode #=> "on-first-retry"
  #
  # @example Development configuration
  #   config = PlaywrightConfiguration.development_config
  #   config.headless #=> false
  #   config.slow_mo #=> 500
  #   config.trace_mode #=> "on"
  #
  # @since 1.0.0
  class PlaywrightConfiguration
    # Default browser type
    DEFAULT_BROWSER = 'chromium'

    # Default headless mode
    DEFAULT_HEADLESS = true

    # Default viewport width
    DEFAULT_VIEWPORT_WIDTH = 1920

    # Default viewport height
    DEFAULT_VIEWPORT_HEIGHT = 1080

    # Default timeout in milliseconds
    DEFAULT_TIMEOUT = 30_000

    # Default slow motion delay in milliseconds
    DEFAULT_SLOW_MO = 0

    # Default trace mode
    DEFAULT_TRACE_MODE = 'off'

    # Valid browser types
    VALID_BROWSERS = %w[chromium firefox webkit].freeze

    # Valid trace modes
    VALID_TRACE_MODES = %w[on off on-first-retry].freeze

    # @return [String] Browser type (chromium, firefox, webkit)
    attr_reader :browser_type

    # @return [Boolean] Headless mode enabled
    attr_reader :headless

    # @return [Hash] Viewport size {width: Integer, height: Integer}
    attr_reader :viewport

    # @return [Integer] Slow motion delay in milliseconds
    attr_reader :slow_mo

    # @return [Integer] Timeout in milliseconds
    attr_reader :timeout

    # @return [Pathname] Path to screenshots directory
    attr_reader :screenshots_path

    # @return [Pathname] Path to traces directory
    attr_reader :traces_path

    # @return [String] Trace mode (on, off, on-first-retry)
    attr_reader :trace_mode

    # Factory method: Create configuration for the given environment.
    #
    # Auto-detects environment using EnvUtils if not specified.
    #
    # @param env [String, nil] Environment name (test, development, production)
    # @return [PlaywrightConfiguration] Environment-specific configuration
    # @example
    #   config = PlaywrightConfiguration.for_environment('test')
    #   config = PlaywrightConfiguration.for_environment # auto-detect
    def self.for_environment(env = nil)
      env ||= Utils::EnvUtils.environment

      if Utils::EnvUtils.ci_environment?
        ci_config
      elsif env == 'development'
        development_config
      else
        local_config
      end
    end

    # Create CI-optimized configuration.
    #
    # CI configuration uses headless mode, longer timeout, and trace-on-retry.
    #
    # @return [PlaywrightConfiguration] CI configuration
    # @example
    #   config = PlaywrightConfiguration.ci_config
    #   config.headless #=> true
    #   config.timeout #=> 60000
    def self.ci_config
      new(
        **base_config,
        headless: true,
        trace_mode: 'on-first-retry',
        options: { slow_mo: 0, timeout: 60_000 }
      )
    end

    # Create local testing configuration.
    #
    # Local configuration allows headless override via env var, shorter timeout.
    #
    # @return [PlaywrightConfiguration] Local configuration
    # @example
    #   config = PlaywrightConfiguration.local_config
    #   config.headless #=> true (configurable via PLAYWRIGHT_HEADLESS)
    #   config.timeout #=> 30000
    def self.local_config
      new(
        **base_config,
        headless: Utils::EnvUtils.get('PLAYWRIGHT_HEADLESS', 'true') == 'true',
        trace_mode: Utils::EnvUtils.get('PLAYWRIGHT_TRACE_MODE', DEFAULT_TRACE_MODE),
        options: {
          slow_mo: Utils::EnvUtils.get('PLAYWRIGHT_SLOW_MO', '0').to_i,
          timeout: DEFAULT_TIMEOUT
        }
      )
    end

    # Create development configuration.
    #
    # Development configuration uses headed mode, slow motion for debugging.
    #
    # @return [PlaywrightConfiguration] Development configuration
    # @example
    #   config = PlaywrightConfiguration.development_config
    #   config.headless #=> false
    #   config.slow_mo #=> 500
    def self.development_config
      new(
        **base_config,
        headless: false,
        trace_mode: 'on',
        options: {
          slow_mo: Utils::EnvUtils.get('PLAYWRIGHT_SLOW_MO', '500').to_i,
          timeout: DEFAULT_TIMEOUT
        }
      )
    end

    # Base configuration shared across all presets.
    #
    # @return [Hash] Base configuration hash
    def self.base_config
      {
        browser_type: Utils::EnvUtils.get('PLAYWRIGHT_BROWSER', DEFAULT_BROWSER),
        viewport: { width: DEFAULT_VIEWPORT_WIDTH, height: DEFAULT_VIEWPORT_HEIGHT }
      }
    end
    private_class_method :base_config

    # Initialize Playwright configuration.
    #
    # @param browser_type [String] Browser type (chromium, firefox, webkit)
    # @param headless [Boolean] Headless mode enabled
    # @param viewport [Hash] Viewport size {width: Integer, height: Integer}
    # @param trace_mode [String] Trace mode (on, off, on-first-retry)
    # @param options [Hash] Additional options (slow_mo, timeout)
    # @option options [Integer] :slow_mo Slow motion delay (default: 0)
    # @option options [Integer] :timeout Timeout in ms (default: 30000)
    # @raise [ArgumentError] If invalid browser_type or trace_mode
    def initialize(browser_type:, headless:, viewport:, trace_mode:, options: {})
      @browser_type = browser_type
      @headless = headless
      @viewport = viewport
      @slow_mo = options.fetch(:slow_mo, DEFAULT_SLOW_MO)
      @timeout = options.fetch(:timeout, DEFAULT_TIMEOUT)
      @trace_mode = trace_mode
      @screenshots_path = Utils::PathUtils.screenshots_path
      @traces_path = Utils::PathUtils.traces_path

      validate!
      ensure_directories_exist
    end

    # Generate browser launch options for Playwright.
    #
    # @return [Hash] Playwright browser launch options
    # @example
    #   config.browser_launch_options
    #   #=> { headless: true, timeout: 60000, slowMo: 0 }
    def browser_launch_options
      {
        headless: @headless,
        timeout: @timeout,
        slowMo: @slow_mo
      }
    end

    # Generate browser context options for Playwright.
    #
    # @return [Hash] Playwright browser context options
    # @example
    #   config.browser_context_options
    #   #=> { viewport: { width: 1920, height: 1080 }, recordVideo: { dir: "..." } }
    def browser_context_options
      {
        viewport: @viewport,
        recordVideo: {
          dir: @screenshots_path.to_s
        }
      }
    end

    private

    # Validate configuration parameters.
    #
    # @raise [ArgumentError] If invalid browser_type or trace_mode
    # @return [void]
    def validate!
      unless VALID_BROWSERS.include?(@browser_type)
        raise ArgumentError,
              "Invalid browser_type: #{@browser_type}. " \
              "Valid options: #{VALID_BROWSERS.join(', ')}"
      end

      return if VALID_TRACE_MODES.include?(@trace_mode)

      raise ArgumentError,
            "Invalid trace_mode: #{@trace_mode}. " \
            "Valid options: #{VALID_TRACE_MODES.join(', ')}"
    end

    # Ensure artifact directories exist.
    #
    # @return [void]
    def ensure_directories_exist
      # Convert Pathname to String to ensure proper path handling
      screenshots_dir = @screenshots_path.to_s
      traces_dir = @traces_path.to_s

      # Validate paths before creating directories
      raise ArgumentError, "Invalid screenshots path: #{screenshots_dir.inspect}" if screenshots_dir.empty? || screenshots_dir == '/path'
      raise ArgumentError, "Invalid traces path: #{traces_dir.inspect}" if traces_dir.empty? || traces_dir == '/path'

      FileUtils.mkdir_p(screenshots_dir)
      FileUtils.mkdir_p(traces_dir)
    rescue Errno::EACCES => e
      # Provide helpful error message for permission issues
      raise Errno::EACCES, 'Permission denied creating Playwright artifact directories. ' \
                           "Screenshots: #{screenshots_dir.inspect}, Traces: #{traces_dir.inspect}. " \
                           "Original error: #{e.message}"
    end
  end
end
