# frozen_string_literal: true

module Testing
  # Abstract interface for artifact storage.
  #
  # Provides a standard interface for storing test artifacts (screenshots, traces)
  # to different storage backends (filesystem, S3, etc.).
  #
  # @abstract Subclass and implement all abstract methods
  #
  # @example Implementing a custom storage backend
  #   class S3Storage < ArtifactStorage
  #     def save_screenshot(name, file_path, metadata = {})
  #       # Upload to S3
  #     end
  #   end
  #
  # @since 1.0.0
  class ArtifactStorage
    # Save a screenshot artifact.
    #
    # @param name [String] Artifact name (sanitized filename without extension)
    # @param file_path [String, Pathname] Path to screenshot file
    # @param metadata [Hash] Optional metadata (test name, timestamp, etc.)
    # @return [void]
    # @raise [NotImplementedError] Must be implemented by subclass
    def save_screenshot(name, file_path, metadata = {})
      raise NotImplementedError, "Subclass must implement save_screenshot"
    end

    # Save a trace artifact.
    #
    # @param name [String] Artifact name (sanitized filename without extension)
    # @param file_path [String, Pathname] Path to trace file
    # @param metadata [Hash] Optional metadata (test name, timestamp, etc.)
    # @return [void]
    # @raise [NotImplementedError] Must be implemented by subclass
    def save_trace(name, file_path, metadata = {})
      raise NotImplementedError, "Subclass must implement save_trace"
    end

    # List all artifacts.
    #
    # @return [Array<Hash>] Array of artifact metadata hashes
    # @raise [NotImplementedError] Must be implemented by subclass
    def list_artifacts
      raise NotImplementedError, "Subclass must implement list_artifacts"
    end

    # Get an artifact by name.
    #
    # @param name [String] Artifact name
    # @return [String, nil] Artifact content (binary) or nil if not found
    # @raise [NotImplementedError] Must be implemented by subclass
    def get_artifact(name)
      raise NotImplementedError, "Subclass must implement get_artifact"
    end

    # Delete an artifact by name.
    #
    # @param name [String] Artifact name
    # @return [Boolean] true if deleted, false if not found
    # @raise [NotImplementedError] Must be implemented by subclass
    def delete_artifact(name)
      raise NotImplementedError, "Subclass must implement delete_artifact"
    end
  end
end
