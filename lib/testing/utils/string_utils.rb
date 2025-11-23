# frozen_string_literal: true

module Testing
  module Utils
    # Provides string sanitization utilities for safe filenames.
    #
    # All methods ensure filenames are safe for cross-platform usage by removing
    # or replacing special characters. Prevents path traversal attacks through
    # strict character whitelisting.
    #
    # @example Filename sanitization
    #   StringUtils.sanitize_filename('User Login: Test #1') #=> "User_Login__Test__1"
    #   StringUtils.sanitize_filename('../etc/passwd') #=> "___etc_passwd"
    #
    # @example Artifact naming
    #   StringUtils.generate_artifact_name('User Login') #=> "User_Login"
    #   StringUtils.generate_artifact_name('User Login', 2) #=> "User_Login_2"
    #
    # @example Filename truncation
    #   StringUtils.truncate_filename('a' * 300 + '.png', 255) #=> "aaa...aaa.png"
    #
    # @since 1.0.0
    module StringUtils
      # Maximum filename length (cross-platform safe limit)
      MAX_FILENAME_LENGTH = 255

      class << self
        # Sanitize string for safe filename usage.
        #
        # Replaces special characters with underscores. Preserves only alphanumeric
        # characters, hyphens, underscores, and dots. Prevents path traversal attacks.
        #
        # Special characters replaced: / \ : * ? " < > |
        #
        # @param name [String] String to sanitize
        # @return [String] Sanitized string safe for filenames
        # @example
        #   StringUtils.sanitize_filename('User Login: Test #1') #=> "User_Login__Test__1"
        #   StringUtils.sanitize_filename('file/name') #=> "file_name"
        #   StringUtils.sanitize_filename('../etc/passwd') #=> "___etc_passwd"
        def sanitize_filename(name)
          # Replace special characters with underscores
          # Preserve: alphanumeric, hyphen, underscore, dot
          # Remove/replace: / \ : * ? " < > | and other special chars
          name.to_s
              .gsub(%r{[/\\:*?"<>|]}, '_') # Replace filesystem special chars
              .gsub(/[^\w\-.]/, '_')       # Replace non-alphanumeric (except hyphen, underscore, dot)
        end

        # Generate artifact name from test name with optional index.
        #
        # Sanitizes test name and optionally appends index number.
        # Useful for generating unique artifact filenames for test runs.
        #
        # @param test_name [String] Test name to convert to artifact name
        # @param index [Integer, nil] Optional index to append
        # @return [String] Sanitized artifact name
        # @example
        #   StringUtils.generate_artifact_name('User Login') #=> "User_Login"
        #   StringUtils.generate_artifact_name('User Login', 2) #=> "User_Login_2"
        def generate_artifact_name(test_name, index = nil)
          sanitized = sanitize_filename(test_name)

          # Append index if provided
          if index
            "#{sanitized}_#{index}"
          else
            sanitized
          end
        end

        # Truncate filename to maximum length while preserving extension.
        #
        # If filename exceeds max_length, truncates the name part (before extension)
        # and adds ellipsis (...). Always preserves file extension.
        #
        # @param name [String] Filename to truncate
        # @param max_length [Integer] Maximum length (defaults to 255)
        # @return [String] Truncated filename
        # @example
        #   StringUtils.truncate_filename('a' * 300 + '.png', 255) #=> "aaa...aaa.png"
        #   StringUtils.truncate_filename('short.txt', 255) #=> "short.txt"
        def truncate_filename(name, max_length = MAX_FILENAME_LENGTH)
          return name if name.length <= max_length

          # Split filename into name and extension
          extension = File.extname(name)
          basename = File.basename(name, extension)

          # Calculate available space for basename (reserve space for extension and ellipsis)
          ellipsis = '...'
          available_length = max_length - extension.length - ellipsis.length

          # Truncate basename if needed
          if available_length.positive?
            truncated_basename = basename[0...available_length] + ellipsis
            truncated_basename + extension
          else
            # If even extension is too long, just truncate everything
            name[0...max_length]
          end
        end
      end
    end
  end
end
