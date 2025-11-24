# frozen_string_literal: true

require 'json'

module DatabaseMigration
  # Progress tracking for database migrations
  # Tracks per-table progress and updates Prometheus metrics
  class ProgressTracker
    attr_reader :tables, :progress

    # Initializes the progress tracker
    # @param tables [Array<String>] list of table names to track
    def initialize(tables:)
      @tables = tables
      @progress = {}
      @progress_file = Rails.root.join('tmp/migration_progress.json')

      tables.each do |table|
        @progress[table] = { completed: 0, total: 0, percentage: 0.0 }
      end

      ensure_tmp_directory
    end

    # Updates progress for a table
    # @param table [String] table name
    # @param completed [Integer] number of completed rows
    # @param total [Integer] total number of rows
    # @return [Hash] updated progress for the table
    def update_progress(table:, completed:, total:)
      raise ArgumentError, "Unknown table: #{table}" unless @tables.include?(table)

      percentage = total.positive? ? (completed.to_f / total * 100).round(2) : 0.0

      @progress[table] = {
        completed: completed,
        total: total,
        percentage: percentage
      }

      # Update Prometheus metric if available
      update_prometheus_metric(table, percentage)

      # Log progress
      log_progress(table, completed, total, percentage)

      # Persist to file
      persist_progress

      @progress[table]
    end

    # Calculates overall progress across all tables
    # @return [Float] overall progress percentage
    def overall_progress
      return 0.0 if @progress.empty?

      total_completed = @progress.values.sum { |p| p[:completed] }
      total_rows = @progress.values.sum { |p| p[:total] }

      return 0.0 if total_rows.zero?

      (total_completed.to_f / total_rows * 100).round(2)
    end

    # Gets progress summary
    # @return [Hash] progress summary
    def summary
      {
        tables: @progress,
        overall: overall_progress,
        total_completed: @progress.values.sum { |p| p[:completed] },
        total_rows: @progress.values.sum { |p| p[:total] },
        completed_tables: @progress.count { |_, p| p[:completed] == p[:total] && p[:total].positive? },
        total_tables: @tables.size,
        timestamp: Time.current.iso8601
      }
    end

    # Converts progress to JSON format
    # @return [String] JSON representation of progress
    def to_json(*_args)
      summary.to_json
    end

    # Loads progress from file
    # @return [Hash, nil] loaded progress or nil if file doesn't exist
    def self.load_from_file
      progress_file = Rails.root.join('tmp/migration_progress.json')

      return nil unless File.exist?(progress_file)

      JSON.parse(File.read(progress_file), symbolize_names: true)
    rescue StandardError => e
      Rails.logger.error "Failed to load progress from file: #{e.message}"
      nil
    end

    # Checks if migration is in progress
    # @return [Boolean] true if migration is in progress
    def self.migration_in_progress?
      File.exist?(Rails.root.join('tmp/migration_in_progress'))
    end

    # Marks migration as started
    def self.mark_migration_started
      FileUtils.touch(Rails.root.join('tmp/migration_in_progress'))
    end

    # Marks migration as completed
    def self.mark_migration_completed
      progress_flag = Rails.root.join('tmp/migration_in_progress')
      File.delete(progress_flag) if File.exist?(progress_flag)
    end

    private

    # Ensures tmp directory exists
    def ensure_tmp_directory
      tmp_dir = Rails.root.join('tmp')
      FileUtils.mkdir_p(tmp_dir) unless Dir.exist?(tmp_dir)
    end

    # Updates Prometheus metric
    # @param table [String] table name
    # @param percentage [Float] progress percentage
    def update_prometheus_metric(table, percentage)
      return unless defined?(DatabaseMetrics)

      DatabaseMetrics.migration_progress.set(
        percentage,
        labels: { table: table }
      )
    rescue StandardError => e
      Rails.logger.warn "Failed to update Prometheus metric: #{e.message}"
    end

    # Logs progress update
    # @param table [String] table name
    # @param completed [Integer] completed rows
    # @param total [Integer] total rows
    # @param percentage [Float] progress percentage
    def log_progress(table, completed, total, percentage)
      Rails.logger.info(
        message: 'Migration progress update',
        table: table,
        completed: completed,
        total: total,
        percentage: percentage,
        timestamp: Time.current.iso8601
      )
    rescue StandardError => e
      # Don't fail on logging errors
      puts "Logging error: #{e.message}"
    end

    # Persists progress to file
    def persist_progress
      File.write(@progress_file, to_json)
    rescue StandardError => e
      Rails.logger.error "Failed to persist progress: #{e.message}"
    end
  end
end
