# frozen_string_literal: true

module DatabaseMigration
  module Services
    # Backup restoration service
    # Handles restoring database backups for PostgreSQL and MySQL
    class BackupRestorer
      attr_reader :adapter

      # Initializes the backup restorer
      # @param adapter [DatabaseAdapter::Base] database adapter
      def initialize(adapter)
        @adapter = adapter
      end

      # Restores database from backup file
      # @param backup_file [String] path to backup file
      # @return [Hash] restore result
      def restore_backup(backup_file)
        raise "Backup file not found: #{backup_file}" unless File.exist?(backup_file)

        case @adapter.adapter_name
        when 'postgresql'
          restore_postgresql_backup(backup_file)
        when 'mysql2'
          restore_mysql_backup(backup_file)
        else
          raise "Restore not supported for adapter: #{@adapter.adapter_name}"
        end
      end

      private

      # Restores PostgreSQL backup
      # @param backup_file [String] path to backup file
      # @return [Hash] restore result
      def restore_postgresql_backup(backup_file)
        cmd = build_psql_command(backup_file)

        success = system(cmd)

        raise "PostgreSQL restore failed. Exit status: #{$?.exitstatus}" unless success

        {
          status: 'success',
          adapter: 'postgresql',
          file: backup_file
        }
      rescue StandardError => e
        {
          status: 'failed',
          adapter: 'postgresql',
          error: e.message
        }
      end

      # Restores MySQL backup
      # @param backup_file [String] path to backup file
      # @return [Hash] restore result
      def restore_mysql_backup(backup_file)
        cmd = build_mysql_command(backup_file)

        success = system(cmd)

        raise "MySQL restore failed. Exit status: #{$?.exitstatus}" unless success

        {
          status: 'success',
          adapter: 'mysql2',
          file: backup_file
        }
      rescue StandardError => e
        {
          status: 'failed',
          adapter: 'mysql2',
          error: e.message
        }
      end

      # Builds psql restore command
      # @param input_file [String] input file path
      # @return [String] command string
      def build_psql_command(input_file)
        [
          'psql',
          '-h', ENV['PG_HOST'] || 'localhost',
          '-U', ENV['PG_USER'] || 'postgres',
          '-d', ENV['PG_DATABASE'] || 'reline_production',
          '<', input_file
        ].join(' ')
      end

      # Builds mysql restore command
      # Uses --defaults-extra-file for secure credential handling
      # @param input_file [String] input file path
      # @return [String] command string
      def build_mysql_command(input_file)
        credentials_file = create_mysql_credentials_file

        cmd_parts = [
          'mysql',
          "--defaults-extra-file=#{credentials_file}",
          ENV['DB_NAME'] || 'reline_production',
          '<', input_file
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
