# frozen_string_literal: true

require 'time'
require 'securerandom'

# rubocop:disable Rails/TimeZone
module Testing
  module Utils
    # Provides timestamp formatting utilities for artifact filenames and correlation IDs.
    #
    # All methods accept an optional Time object parameter, defaulting to Time.now.
    # Correlation IDs are guaranteed unique through timestamp and random hex combination.
    #
    # @example Timestamp formatting
    #   TimeUtils.format_for_filename #=> "20251123-143052"
    #   TimeUtils.format_iso8601 #=> "2025-11-23T14:30:52+09:00"
    #   TimeUtils.format_human #=> "2025-11-23 14:30:52"
    #
    # @example Correlation IDs
    #   TimeUtils.generate_correlation_id #=> "test-run-20251123-143052-a3f2c1"
    #   TimeUtils.generate_correlation_id('rspec') #=> "rspec-20251123-143052-b4e3d2"
    #
    # @since 1.0.0
    module TimeUtils
      class << self
        # Format timestamp for safe filename usage.
        #
        # Returns format: YYYYMMDD-HHMMSS (no colons or slashes for cross-platform compatibility).
        #
        # @param time [Time] Time object to format (defaults to Time.now)
        # @return [String] Formatted timestamp safe for filenames
        # @example
        #   TimeUtils.format_for_filename #=> "20251123-143052"
        #   TimeUtils.format_for_filename(Time.new(2025, 1, 1, 12, 0, 0)) #=> "20250101-120000"
        def format_for_filename(time = Time.now)
          # Format: YYYYMMDD-HHMMSS
          # Safe for filenames (no colons, slashes, or spaces)
          time.strftime('%Y%m%d-%H%M%S')
        end

        # Format timestamp in ISO 8601 format.
        #
        # Returns format: YYYY-MM-DDTHH:MM:SS+TZ (standard for JSON/logs).
        #
        # @param time [Time] Time object to format (defaults to Time.now)
        # @return [String] ISO 8601 formatted timestamp
        # @example
        #   TimeUtils.format_iso8601 #=> "2025-11-23T14:30:52+09:00"
        def format_iso8601(time = Time.now)
          # ISO 8601 format with timezone
          time.iso8601
        end

        # Format timestamp in human-readable format.
        #
        # Returns format: YYYY-MM-DD HH:MM:SS (easy to read in logs).
        #
        # @param time [Time] Time object to format (defaults to Time.now)
        # @return [String] Human-readable timestamp
        # @example
        #   TimeUtils.format_human #=> "2025-11-23 14:30:52"
        def format_human(time = Time.now)
          # Human-readable format
          time.strftime('%Y-%m-%d %H:%M:%S')
        end

        # Generate unique correlation ID for test runs and artifacts.
        #
        # Combines prefix, timestamp, and random hex for guaranteed uniqueness.
        # Format: prefix-YYYYMMDD-HHMMSS-XXXXXX
        #
        # @param prefix [String] Prefix for correlation ID (defaults to 'test-run')
        # @return [String] Unique correlation ID
        # @example
        #   TimeUtils.generate_correlation_id #=> "test-run-20251123-143052-a3f2c1"
        #   TimeUtils.generate_correlation_id('rspec') #=> "rspec-20251123-143052-b4e3d2"
        def generate_correlation_id(prefix = 'test-run')
          # Combine prefix, timestamp, and random hex for uniqueness
          timestamp = format_for_filename
          random_hex = SecureRandom.hex(3) # 6 characters

          "#{prefix}-#{timestamp}-#{random_hex}"
        end
      end
    end
  end
end
# rubocop:enable Rails/TimeZone
