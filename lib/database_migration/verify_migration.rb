# frozen_string_literal: true

require 'json'
require 'pg'
require 'mysql2'
require 'concurrent'

module DatabaseMigration
  # Data Migration Verification Script
  # Verifies data integrity after migration from PostgreSQL to MySQL
  #
  # Usage:
  #   ruby lib/database_migration/verify_migration.rb
  #
  # Environment Variables Required:
  #   PostgreSQL: PG_HOST, PG_DATABASE, PG_USER, PG_PASSWORD
  #   MySQL: MYSQL_HOST, MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD
  class VerifyMigration
    TABLES = %w[alarm_contents contents feedbacks line_groups operators].freeze
    # Number of concurrent threads for parallel verification
    MAX_CONCURRENCY = 3

    attr_reader :pg_conn, :mysql_conn, :results

    def initialize
      @results = {
        timestamp: Time.now.utc.iso8601,
        tables: [],
        summary: {
          total_tables: TABLES.size,
          tables_matched: 0,
          tables_mismatched: 0,
          total_source_rows: 0,
          total_target_rows: 0,
          all_matched: false
        }
      }
      @results_mutex = Mutex.new
    end

    # Main execution method
    def run
      puts '=' * 80
      puts 'DATABASE MIGRATION VERIFICATION'
      puts '=' * 80
      puts "Timestamp: #{@results[:timestamp]}"
      puts

      establish_connections
      verify_all_tables
      generate_summary
      save_results
      display_final_report

      exit(@results[:summary][:all_matched] ? 0 : 1)
    rescue StandardError => e
      puts
      puts "❌ VERIFICATION FAILED: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    ensure
      close_connections
    end

    private

    # Establishes database connections
    def establish_connections
      puts 'Connecting to databases...'

      @pg_conn = PG.connect(
        host: ENV.fetch('PG_HOST'),
        dbname: ENV.fetch('PG_DATABASE'),
        user: ENV.fetch('PG_USER'),
        password: ENV.fetch('PG_PASSWORD')
      )
      puts "✅ Connected to PostgreSQL: #{ENV['PG_HOST']}/#{ENV['PG_DATABASE']}"

      @mysql_conn = Mysql2::Client.new(
        host: ENV.fetch('MYSQL_HOST'),
        database: ENV.fetch('MYSQL_DATABASE'),
        username: ENV.fetch('MYSQL_USER'),
        password: ENV.fetch('MYSQL_PASSWORD'),
        encoding: 'utf8mb4'
      )
      puts "✅ Connected to MySQL: #{ENV['MYSQL_HOST']}/#{ENV['MYSQL_DATABASE']}"
      puts
    rescue KeyError => e
      raise "Missing environment variable: #{e.message}"
    rescue PG::Error, Mysql2::Error => e
      raise "Database connection failed: #{e.message}"
    end

    # Verifies all tables (parallel execution)
    def verify_all_tables
      puts "Verifying #{TABLES.size} tables in parallel (max #{MAX_CONCURRENCY} threads)..."
      puts

      # Create a thread pool with fixed size
      pool = Concurrent::FixedThreadPool.new(MAX_CONCURRENCY)

      # Submit verification tasks to the pool
      futures = TABLES.map do |table|
        Concurrent::Future.execute(executor: pool) do
          verify_table(table)
        end
      end

      # Wait for all tasks to complete
      futures.each(&:wait)

      # Shutdown the pool
      pool.shutdown
      pool.wait_for_termination
    end

    # Verifies a single table (thread-safe)
    def verify_table(table)
      puts "📋 Table: #{table}"

      # Get row counts
      pg_count = get_row_count(@pg_conn, table, :postgresql)
      mysql_count = get_row_count(@mysql_conn, table, :mysql)

      # Calculate checksums
      pg_checksum = get_sample_checksum(@pg_conn, table, :postgresql)
      mysql_checksum = get_sample_checksum(@mysql_conn, table, :mysql)

      match = (pg_count == mysql_count)
      checksum_match = (pg_checksum == mysql_checksum)

      table_result = {
        table: table,
        source_count: pg_count,
        target_count: mysql_count,
        match: match,
        difference: pg_count - mysql_count,
        source_checksum: pg_checksum,
        target_checksum: mysql_checksum,
        checksum_match: checksum_match
      }

      # Thread-safe results storage
      @results_mutex.synchronize do
        @results[:tables] << table_result
      end

      # Display results
      puts "  PostgreSQL rows: #{pg_count}"
      puts "  MySQL rows: #{mysql_count}"
      puts "  Difference: #{table_result[:difference]}"
      puts "  Row count match: #{match ? '✅ YES' : '❌ NO'}"
      puts "  Checksum match: #{checksum_match ? '✅ YES' : '⚠️  NO (sample-based)'}"
      puts
    rescue StandardError => e
      puts "  ❌ Error: #{e.message}"

      # Thread-safe error storage
      @results_mutex.synchronize do
        @results[:tables] << {
          table: table,
          error: e.message,
          match: false
        }
      end
      puts
    end

    # Gets row count for a table
    # Uses proper quoting to prevent SQL injection
    def get_row_count(connection, table, adapter)
      case adapter
      when :postgresql
        # PG gem: Use quote_ident for table name quoting
        quoted_table = PG::Connection.quote_ident(table)
        result = connection.exec("SELECT COUNT(*) FROM #{quoted_table}")
        result[0]['count'].to_i
      when :mysql
        # MySQL2: Use backticks for table name quoting
        quoted_table = "`#{connection.escape(table)}`"
        result = connection.query("SELECT COUNT(*) FROM #{quoted_table}")
        result.first.values.first
      end
    rescue StandardError => e
      raise "Failed to count rows in #{table} (#{adapter}): #{e.message}"
    end

    # Gets sample checksum for a table (first 1000 rows ordered by primary key)
    # Uses parameterized queries and proper quoting to prevent SQL injection
    def get_sample_checksum(connection, table, adapter, sample_size: 1000)
      # Validate sample_size to prevent injection
      raise ArgumentError, 'sample_size must be a positive integer' unless sample_size.is_a?(Integer) && sample_size.positive?

      case adapter
      when :postgresql
        # PG gem: Use quote_ident for table name quoting and parameterized query for limit
        quoted_table = PG::Connection.quote_ident(table)
        result = connection.exec_params(
          "SELECT * FROM #{quoted_table} ORDER BY id LIMIT $1",
          [sample_size]
        )
        rows = result.map { |row| row.to_h }
        Digest::SHA256.hexdigest(rows.to_json)
      when :mysql
        # MySQL2: Use backticks for table name quoting and safe integer for limit
        quoted_table = "`#{connection.escape(table)}`"
        # sample_size is validated as integer above, safe to interpolate
        result = connection.query(
          "SELECT * FROM #{quoted_table} ORDER BY id LIMIT #{sample_size.to_i}",
          as: :hash
        )
        rows = result.to_a
        Digest::SHA256.hexdigest(rows.to_json)
      end
    rescue StandardError => e
      # Checksum failure is not critical, log warning
      warn "⚠️  Failed to calculate checksum for #{table} (#{adapter}): #{e.message}"
      'checksum_error'
    end

    # Generates summary statistics
    def generate_summary
      matched = @results[:tables].count { |t| t[:match] }
      mismatched = @results[:tables].count { |t| !t[:match] }

      @results[:summary][:tables_matched] = matched
      @results[:summary][:tables_mismatched] = mismatched
      @results[:summary][:total_source_rows] = @results[:tables].sum { |t| t[:source_count] || 0 }
      @results[:summary][:total_target_rows] = @results[:tables].sum { |t| t[:target_count] || 0 }
      @results[:summary][:all_matched] = (mismatched == 0)
    end

    # Saves results to JSON file
    def save_results
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = "tmp/migration_verification_#{timestamp}.json"

      # Ensure tmp directory exists
      Dir.mkdir('tmp') unless Dir.exist?('tmp')

      File.write(filename, JSON.pretty_generate(@results))
      puts "💾 Results saved to: #{filename}"
      puts
    end

    # Displays final report
    def display_final_report
      puts '=' * 80
      puts 'VERIFICATION SUMMARY'
      puts '=' * 80
      puts "Total tables: #{@results[:summary][:total_tables]}"
      puts "Tables matched: #{@results[:summary][:tables_matched]} ✅"
      puts "Tables mismatched: #{@results[:summary][:tables_mismatched]} ❌"
      puts "Total source rows (PostgreSQL): #{@results[:summary][:total_source_rows]}"
      puts "Total target rows (MySQL): #{@results[:summary][:total_target_rows]}"
      puts

      if @results[:summary][:all_matched]
        puts '✅ ALL TABLES VERIFIED SUCCESSFULLY'
      else
        puts '❌ VERIFICATION FAILED - MISMATCHES DETECTED'
        puts
        puts 'Mismatched tables:'
        @results[:tables].select { |t| !t[:match] }.each do |table|
          puts "  - #{table[:table]}: #{table[:difference]} row difference"
        end
      end
      puts '=' * 80
    end

    # Closes database connections
    def close_connections
      @pg_conn&.close
      @mysql_conn&.close
    end
  end
end

# Run verification if executed directly
if __FILE__ == $PROGRAM_NAME
  require 'digest'
  DatabaseMigration::VerifyMigration.new.run
end
