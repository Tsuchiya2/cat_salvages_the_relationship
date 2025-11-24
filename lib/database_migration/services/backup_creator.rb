# frozen_string_literal: true

module DatabaseMigration
  module Services
    # Backup creation service
    # Handles creating database backups for PostgreSQL and MySQL
    class BackupCreator
      attr_reader :adapter, :backup_dir

      # Initializes the backup creator
      # @param adapter [DatabaseAdapter::Base] database adapter
      # @param backup_dir [String] backup directory path
      def initialize(adapter, backup_dir)
        @adapter = adapter
        @backup_dir = backup_dir
      end

      # Creates a database backup
      # @return [Hash] backup result including file path
      def create_backup
        ensure_backup_directory

        case @adapter.adapter_name
        when 'postgresql'
          create_postgresql_backup
        when 'mysql2'
          create_mysql_backup
        else
          raise "Backup not supported for adapter: #{@adapter.adapter_name}"
        end
      end

      private

      # Ensures backup directory exists
      def ensure_backup_directory
        FileUtils.mkdir_p(@backup_dir) unless Dir.exist?(@backup_dir)
      end

      # Creates PostgreSQL backup using pg_dump
      # @return [Hash] backup result
      def create_postgresql_backup
        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        backup_file = File.join(@backup_dir, "backup_postgresql_#{timestamp}.sql")

        cmd = build_pg_dump_command(backup_file)

        success = system(cmd)

        raise "PostgreSQL backup failed. Exit status: #{$?.exitstatus}" unless success

        {
          status: 'success',
          adapter: 'postgresql',
          file: backup_file,
          size: File.size(backup_file),
          timestamp: timestamp
        }
      rescue StandardError => e
        {
          status: 'failed',
          adapter: 'postgresql',
          error: e.message
        }
      end

      # Creates MySQL backup using mysqldump
      # @return [Hash] backup result
      def create_mysql_backup
        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        backup_file = File.join(@backup_dir, "backup_mysql_#{timestamp}.sql")

        cmd = build_mysqldump_command(backup_file)

        success = system(cmd)

        raise "MySQL backup failed. Exit status: #{$?.exitstatus}" unless success

        {
          status: 'success',
          adapter: 'mysql2',
          file: backup_file,
          size: File.size(backup_file),
          timestamp: timestamp
        }
      rescue StandardError => e
        {
          status: 'failed',
          adapter: 'mysql2',
          error: e.message
        }
      end

      # Builds pg_dump command
      # @param output_file [String] output file path
      # @return [String] command string
      def build_pg_dump_command(output_file)
        [
          'pg_dump',
          '-h', ENV['PG_HOST'] || 'localhost',
          '-U', ENV['PG_USER'] || 'postgres',
          '-d', ENV['PG_DATABASE'] || 'reline_production',
          '-f', output_file,
          '--no-owner',
          '--no-acl'
        ].join(' ')
      end

      # Builds mysqldump command
      # Uses --defaults-extra-file for secure credential handling
      # @param output_file [String] output file path
      # @return [String] command string
      def build_mysqldump_command(output_file)
        credentials_file = create_mysql_credentials_file

        cmd_parts = [
          'mysqldump',
          "--defaults-extra-file=#{credentials_file}",
          ENV['DB_NAME'] || 'reline_production',
          '>', output_file
        ]

        cmd_parts.join(' ')
      ensure
        # Clean up credentials file after command execution
        cleanup_credentials_file(credentials_file) if credentials_file
      end

      # Creates a temporary MySQL credentials file with restrictive permissions
      # @return [String] path to credentials file
      def create_mysql_credentials_file
        require 'tempfile'

        file = Tempfile.new(['mysql_credentials', '.cnf'])
        file.chmod(0o600) # Set restrictive permissions (owner read/write only)

        # Write MySQL credentials in INI format
        file.write(<<~CNF)
          [client]
          host=#{ENV['DB_HOST'] || 'localhost'}
          user=#{ENV['DB_USERNAME'] || 'root'}
          password=#{ENV['DB_PASSWORD']}
        CNF

        file.close
        file.path
      end

      # Cleans up temporary credentials file
      # @param credentials_file [String] path to credentials file
      def cleanup_credentials_file(credentials_file)
        File.delete(credentials_file) if credentials_file && File.exist?(credentials_file)
      rescue StandardError => e
        Rails.logger.warn "Failed to cleanup credentials file: #{e.message}"
      end
    end
  end
end
