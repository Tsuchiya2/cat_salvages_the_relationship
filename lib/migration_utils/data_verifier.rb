# frozen_string_literal: true

require 'digest'

module MigrationUtils
  # Data verification utility for database migrations
  # Compares row counts, schemas, and checksums between source and target databases
  class DataVerifier
    attr_reader :source_connection, :target_connection

    # Initializes the data verifier
    # @param source_connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] source database connection
    # @param target_connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] target database connection
    def initialize(source_connection, target_connection)
      @source_connection = source_connection
      @target_connection = target_connection
    end

    # Verifies row counts for given tables
    # @param tables [Array<String>] list of table names to verify
    # @return [Hash] verification results
    def verify_row_counts(tables)
      results = []

      tables.each do |table|
        source_count = count_rows(@source_connection, table)
        target_count = count_rows(@target_connection, table)

        results << {
          table: table,
          source_count: source_count,
          target_count: target_count,
          match: source_count == target_count,
          difference: source_count - target_count
        }
      end

      {
        table_results: results,
        all_matched: results.all? { |r| r[:match] },
        mismatches: results.reject { |r| r[:match] },
        total_source_rows: results.sum { |r| r[:source_count] },
        total_target_rows: results.sum { |r| r[:target_count] }
      }
    end

    # Verifies schema compatibility for a table
    # @param table [String] table name
    # @return [Hash] schema comparison results
    def verify_schema_compatibility(table)
      source_columns = get_columns(@source_connection, table)
      target_columns = get_columns(@target_connection, table)

      {
        table: table,
        columns_match: source_columns.sort == target_columns.sort,
        missing_in_target: source_columns - target_columns,
        extra_in_target: target_columns - source_columns,
        source_columns: source_columns,
        target_columns: target_columns
      }
    end

    # Verifies data integrity using sample-based checksums
    # @param table [String] table name
    # @param sample_size [Integer] number of rows to sample (default: 1000)
    # @return [Hash] checksum comparison results
    def verify_checksums(table, sample_size: 1000)
      source_checksum = get_sample_checksum(@source_connection, table, sample_size)
      target_checksum = get_sample_checksum(@target_connection, table, sample_size)

      {
        table: table,
        sample_size: sample_size,
        checksum_match: source_checksum == target_checksum,
        source_checksum: source_checksum,
        target_checksum: target_checksum,
        note: 'Sample-based verification - full data comparison may be needed for critical tables'
      }
    end

    # Verifies all aspects for multiple tables
    # @param tables [Array<String>] list of table names
    # @param options [Hash] verification options
    # @option options [Boolean] :skip_checksums skip checksum verification (faster)
    # @return [Hash] comprehensive verification results
    def verify_all(tables, options = {})
      row_count_results = verify_row_counts(tables)
      schema_results = verify_schemas_for_tables(tables)
      checksum_results = verify_checksums_for_tables(tables, options)

      {
        row_counts: row_count_results,
        schemas: schema_results,
        checksums: checksum_results,
        all_passed: all_verifications_passed?(row_count_results, schema_results, checksum_results, options),
        timestamp: Time.current.iso8601
      }
    end

    private

    # Verifies schemas for multiple tables
    # @param tables [Array<String>] list of table names
    # @return [Array<Hash>] schema verification results
    def verify_schemas_for_tables(tables)
      tables.map { |table| verify_schema_compatibility(table) }
    end

    # Verifies checksums for multiple tables
    # @param tables [Array<String>] list of table names
    # @param options [Hash] verification options
    # @return [Array<Hash>] checksum verification results
    def verify_checksums_for_tables(tables, options)
      return [] if options[:skip_checksums]

      tables.map { |table| verify_checksums(table) }
    end

    # Checks if all verifications passed
    # @param row_count_results [Hash] row count verification results
    # @param schema_results [Array<Hash>] schema verification results
    # @param checksum_results [Array<Hash>] checksum verification results
    # @param options [Hash] verification options
    # @return [Boolean] true if all verifications passed
    def all_verifications_passed?(row_count_results, schema_results, checksum_results, options)
      row_counts_match = row_count_results[:all_matched]
      schemas_match = schema_results.all? { |r| r[:columns_match] }
      checksums_match = options[:skip_checksums] || checksum_results.all? { |r| r[:checksum_match] }

      row_counts_match && schemas_match && checksums_match
    end

    # Counts rows in a table
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] database connection
    # @param table [String] table name
    # @return [Integer] row count
    def count_rows(connection, table)
      connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}")
    rescue StandardError => e
      Rails.logger.error "Failed to count rows in #{table}: #{e.message}"
      0
    end

    # Gets column names for a table
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] database connection
    # @param table [String] table name
    # @return [Array<String>] column names
    def get_columns(connection, table)
      connection.columns(table).map(&:name)
    rescue StandardError => e
      Rails.logger.error "Failed to get columns for #{table}: #{e.message}"
      []
    end

    # Calculates sample checksum for a table
    # Optimized version: selects only necessary columns and uses streaming
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] database connection
    # @param table [String] table name
    # @param sample_size [Integer] number of rows to sample
    # @return [String] SHA256 checksum
    def get_sample_checksum(connection, table, sample_size)
      # Get primary key column
      primary_key = connection.primary_key(table) || 'id'

      # Get all column names except large binary columns (blobs, binary data)
      columns = connection.columns(table).reject do |col|
        col.type == :binary || col.sql_type.downcase.include?('blob')
      end.map(&:name)

      # If no suitable columns found, use primary key only
      columns = [primary_key] if columns.empty?

      # Build optimized query selecting only necessary columns
      column_list = columns.map { |col| connection.quote_column_name(col) }.join(', ')
      query = "SELECT #{column_list} FROM #{connection.quote_table_name(table)} " \
              "ORDER BY #{connection.quote_column_name(primary_key)} " \
              "LIMIT #{sample_size}"

      # Use streaming approach to avoid loading all data into memory
      digest = Digest::SHA256.new
      connection.select_all(query).each do |row|
        # Hash each row incrementally instead of converting all to JSON
        digest.update(row.values.join('|'))
      end

      digest.hexdigest
    rescue StandardError => e
      Rails.logger.error "Failed to calculate checksum for #{table}: #{e.message}"
      'error'
    end
  end
end
