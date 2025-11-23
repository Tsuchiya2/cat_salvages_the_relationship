# frozen_string_literal: true

module Testing
  module Utils
    # Provides framework-agnostic environment detection utilities.
    #
    # Works with or without Rails, using Rails.env when available
    # and RACK_ENV/APP_ENV otherwise. Detects CI environments from
    # environment variables.
    #
    # @example Environment detection
    #   EnvUtils.environment #=> "test"
    #   EnvUtils.test_environment? #=> true
    #   EnvUtils.ci_environment? #=> false
    #
    # @example Environment variables
    #   EnvUtils.get('PLAYWRIGHT_BROWSER', 'chromium') #=> "chromium"
    #
    # @since 1.0.0
    module EnvUtils
      class << self
        # Get current environment name.
        #
        # Detects Rails.env if Rails is available, otherwise uses RACK_ENV,
        # APP_ENV, or falls back to 'development'.
        #
        # @return [String] Current environment name
        # @example
        #   EnvUtils.environment #=> "test"
        def environment
          if defined?(Rails) && Rails.respond_to?(:env) && Rails.env
            Rails.env.to_s
          else
            # Try common environment variables in order of preference
            ENV['RACK_ENV'] || ENV['APP_ENV'] || 'development'
          end
        end

        # Check if running in test environment.
        #
        # @return [Boolean] True if test environment
        # @example
        #   EnvUtils.test_environment? #=> true
        def test_environment?
          environment == 'test'
        end

        # Check if running in CI environment.
        #
        # Detects GitHub Actions (GITHUB_ACTIONS=true) or generic CI (CI=true).
        #
        # @return [Boolean] True if CI environment
        # @example
        #   EnvUtils.ci_environment? #=> true
        def ci_environment?
          # Check for GitHub Actions
          return true if ENV['GITHUB_ACTIONS'] == 'true'

          # Check for generic CI environment variable
          ENV['CI'] == 'true'
        end

        # Check if running in production environment.
        #
        # @return [Boolean] True if production environment
        # @example
        #   EnvUtils.production_environment? #=> false
        def production_environment?
          environment == 'production'
        end

        # Check if running in development environment.
        #
        # @return [Boolean] True if development environment
        # @example
        #   EnvUtils.development_environment? #=> false
        def development_environment?
          environment == 'development'
        end

        # Get environment variable with fallback default.
        #
        # @param key [String] Environment variable name
        # @param default [String, nil] Default value if not set
        # @return [String, nil] Environment variable value or default
        # @example
        #   EnvUtils.get('PLAYWRIGHT_BROWSER', 'chromium') #=> "chromium"
        #   EnvUtils.get('MISSING_VAR', 'default') #=> "default"
        #   EnvUtils.get('MISSING_VAR') #=> nil
        def get(key, default = nil)
          ENV.fetch(key, default)
        end
      end
    end
  end
end
