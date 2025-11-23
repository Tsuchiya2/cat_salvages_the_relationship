# frozen_string_literal: true

require 'pathname'

module Testing
  module Utils
    # Provides framework-agnostic path management utilities.
    #
    # Works with or without Rails, using Rails.root when available
    # and Dir.pwd otherwise. All paths are returned as Pathname objects
    # for cross-platform compatibility.
    #
    # @example Basic usage
    #   PathUtils.root_path #=> #<Pathname:/path/to/project>
    #   PathUtils.screenshots_path #=> #<Pathname:/path/to/project/tmp/screenshots>
    #
    # @example Custom root path
    #   PathUtils.root_path = '/custom/path'
    #   PathUtils.tmp_path #=> #<Pathname:/custom/path/tmp>
    #
    # @since 1.0.0
    module PathUtils
      class << self
        # Get project root path (works with or without Rails).
        #
        # Detects Rails.root if Rails is available, otherwise uses Dir.pwd.
        # Falls back to custom root path if set via root_path=.
        #
        # @return [Pathname] Project root path
        # @example
        #   PathUtils.root_path #=> #<Pathname:/path/to/project>
        def root_path
          return @custom_root_path if @custom_root_path

          # Check if Rails is defined and has a root method
          if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
            Pathname.new(Rails.root)
          else
            # Fall back to current working directory
            Pathname.new(Dir.pwd)
          end
        end

        # Set custom root path (overrides Rails.root and Dir.pwd).
        #
        # @param path [String, Pathname] Custom root path
        # @return [Pathname] The set custom root path
        # @example
        #   PathUtils.root_path = '/custom/path'
        def root_path=(path)
          @custom_root_path = Pathname.new(path)
        end

        # Get tmp directory path.
        #
        # @return [Pathname] Path to tmp directory
        # @example
        #   PathUtils.tmp_path #=> #<Pathname:/path/to/project/tmp>
        def tmp_path
          root_path.join('tmp')
        end

        # Get screenshots directory path.
        #
        # @return [Pathname] Path to screenshots directory
        # @example
        #   PathUtils.screenshots_path #=> #<Pathname:/path/to/project/tmp/screenshots>
        def screenshots_path
          tmp_path.join('screenshots')
        end

        # Get traces directory path (for Playwright traces).
        #
        # @return [Pathname] Path to traces directory
        # @example
        #   PathUtils.traces_path #=> #<Pathname:/path/to/project/tmp/traces>
        def traces_path
          tmp_path.join('traces')
        end

        # Get coverage directory path.
        #
        # @return [Pathname] Path to coverage directory
        # @example
        #   PathUtils.coverage_path #=> #<Pathname:/path/to/project/coverage>
        def coverage_path
          root_path.join('coverage')
        end
      end
    end
  end
end
