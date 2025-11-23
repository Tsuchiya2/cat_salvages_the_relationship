# frozen_string_literal: true

require_relative 'artifact_storage'
require_relative 'utils/path_utils'
require_relative 'utils/string_utils'
require_relative 'utils/time_utils'
require 'fileutils'
require 'json'

module Testing
  # Filesystem-based artifact storage implementation.
  #
  # Stores screenshots and traces to local filesystem with metadata support.
  # Metadata is saved as JSON files alongside artifacts.
  #
  # @example Basic usage
  #   storage = FileSystemStorage.new
  #   storage.save_screenshot('test-failure', '/tmp/screenshot.png', {
  #     test_name: 'User login spec',
  #     timestamp: Time.now.iso8601
  #   })
  #
  # @example Custom base path
  #   storage = FileSystemStorage.new(base_path: '/custom/path')
  #
  # @since 1.0.0
  class FileSystemStorage < ArtifactStorage
    # @return [Pathname] Base path for artifact storage
    attr_reader :base_path

    # Initialize filesystem storage.
    #
    # @param base_path [String, Pathname] Base path for storage (default: tmp/)
    def initialize(base_path: Utils::PathUtils.tmp_path)
      @base_path = Pathname.new(base_path)
      ensure_directories_exist
    end

    # Save a screenshot artifact to filesystem.
    #
    # @param name [String] Artifact name (will be sanitized)
    # @param file_path [String, Pathname] Path to screenshot file
    # @param metadata [Hash] Optional metadata to save alongside screenshot
    # @return [Pathname] Path to saved screenshot
    # @raise [Errno::ENOENT] If source file doesn't exist
    def save_screenshot(name, file_path, metadata = {})
      sanitized_name = Utils::StringUtils.sanitize_filename(name)
      destination = screenshots_path.join("#{sanitized_name}.png")

      FileUtils.cp(file_path, destination)
      save_metadata(destination, metadata)

      destination
    end

    # Save a trace artifact to filesystem.
    #
    # @param name [String] Artifact name (will be sanitized)
    # @param file_path [String, Pathname] Path to trace file
    # @param metadata [Hash] Optional metadata to save alongside trace
    # @return [Pathname] Path to saved trace
    # @raise [Errno::ENOENT] If source file doesn't exist
    def save_trace(name, file_path, metadata = {})
      sanitized_name = Utils::StringUtils.sanitize_filename(name)
      destination = traces_path.join("#{sanitized_name}.zip")

      FileUtils.cp(file_path, destination)
      save_metadata(destination, metadata)

      destination
    end

    # List all artifacts (screenshots and traces).
    #
    # @return [Array<Hash>] Array of artifact metadata hashes
    #   Each hash contains: { name:, path:, type:, metadata: }
    def list_artifacts
      (list_screenshots_artifacts + list_traces_artifacts).sort_by { |a| a[:name] }
    end

    # Get an artifact by name.
    #
    # @param name [String] Artifact name (without extension)
    # @return [String, nil] Artifact content (binary) or nil if not found
    def get_artifact(name)
      sanitized_name = Utils::StringUtils.sanitize_filename(name)

      # Try screenshot first
      screenshot_path = screenshots_path.join("#{sanitized_name}.png")
      return File.binread(screenshot_path) if screenshot_path.exist?

      # Try trace
      trace_path = traces_path.join("#{sanitized_name}.zip")
      return File.binread(trace_path) if trace_path.exist?

      nil
    end

    # Delete an artifact by name.
    #
    # @param name [String] Artifact name (without extension)
    # @return [Boolean] true if deleted, false if not found
    def delete_artifact(name)
      sanitized_name = Utils::StringUtils.sanitize_filename(name)
      deleted = false

      # Try screenshot
      screenshot_path = screenshots_path.join("#{sanitized_name}.png")
      if screenshot_path.exist?
        File.delete(screenshot_path)
        delete_metadata(screenshot_path)
        deleted = true
      end

      # Try trace
      trace_path = traces_path.join("#{sanitized_name}.zip")
      if trace_path.exist?
        File.delete(trace_path)
        delete_metadata(trace_path)
        deleted = true
      end

      deleted
    end

    private

    # Get screenshots directory path.
    #
    # @return [Pathname] Screenshots directory path
    def screenshots_path
      @base_path.join('screenshots')
    end

    # Get traces directory path.
    #
    # @return [Pathname] Traces directory path
    def traces_path
      @base_path.join('traces')
    end

    # Save metadata as JSON file alongside artifact.
    #
    # @param artifact_path [Pathname] Path to artifact file
    # @param metadata [Hash] Metadata to save
    # @return [void]
    def save_metadata(artifact_path, metadata)
      return if metadata.empty?

      metadata_path = artifact_path.sub_ext('.metadata.json')
      enhanced_metadata = metadata.merge(
        saved_at: Utils::TimeUtils.format_iso8601,
        file_size: File.size(artifact_path)
      )

      File.write(metadata_path, JSON.pretty_generate(enhanced_metadata))
    end

    # Load metadata from JSON file.
    #
    # @param metadata_path [Pathname] Path to metadata file
    # @return [Hash] Metadata hash or empty hash if not found
    def load_metadata(metadata_path)
      return {} unless metadata_path.exist?

      JSON.parse(File.read(metadata_path), symbolize_names: true)
    rescue JSON::ParserError
      {}
    end

    # Delete metadata file for artifact.
    #
    # @param artifact_path [Pathname] Path to artifact file
    # @return [void]
    def delete_metadata(artifact_path)
      metadata_path = artifact_path.sub_ext('.metadata.json')
      File.delete(metadata_path) if metadata_path.exist?
    end

    # Ensure storage directories exist.
    #
    # @return [void]
    def ensure_directories_exist
      FileUtils.mkdir_p(screenshots_path)
      FileUtils.mkdir_p(traces_path)
    end

    # List screenshot artifacts.
    #
    # @return [Array<Hash>] Array of screenshot artifact metadata
    def list_screenshots_artifacts
      Dir.glob(screenshots_path.join('*.png')).map do |screenshot_path|
        build_artifact_hash(screenshot_path, 'screenshot', '.png')
      end
    end

    # List trace artifacts.
    #
    # @return [Array<Hash>] Array of trace artifact metadata
    def list_traces_artifacts
      Dir.glob(traces_path.join('*.zip')).map do |trace_path|
        build_artifact_hash(trace_path, 'trace', '.zip')
      end
    end

    # Build artifact hash from file path.
    #
    # @param file_path [String] Path to artifact file
    # @param type [String] Artifact type ('screenshot' or 'trace')
    # @param extension [String] File extension
    # @return [Hash] Artifact metadata hash
    def build_artifact_hash(file_path, type, extension)
      name = File.basename(file_path, extension)
      metadata_path = Pathname.new(file_path).sub_ext('.metadata.json')
      metadata = load_metadata(metadata_path)

      {
        name: name,
        path: file_path,
        type: type,
        metadata: metadata
      }
    end
  end
end
