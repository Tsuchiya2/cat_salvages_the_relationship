# frozen_string_literal: true

require_relative 'backup_creator'
require_relative 'backup_restorer'
require_relative 'backup_validator'

module DatabaseMigration
  module Services
    # Database backup service (Facade)
    # Delegates to specialized service objects for backup operations
    # Maintains backward compatibility with existing API
    class BackupService
      attr_reader :adapter, :config

      # Initializes the backup service
      # @param adapter [DatabaseAdapter::Base] database adapter
      # @param config [Hash] backup configuration
      def initialize(adapter, config = {})
        @adapter = adapter
        @config = config
        @backup_dir = config[:backup_dir] || 'db/backups'
      end

      # Creates a database backup
      # @return [Hash] backup result including file path
      delegate :create_backup, to: :backup_creator

      # Restores database from backup file
      # @param backup_file [String] path to backup file
      # @return [Hash] restore result
      delegate :restore_backup, to: :backup_restorer

      # Lists available backup files
      # @return [Array<Hash>] list of backup files with metadata
      delegate :list_backups, to: :backup_validator

      private

      # Gets backup creator instance
      # @return [BackupCreator] backup creator
      def backup_creator
        @backup_creator ||= BackupCreator.new(@adapter, @backup_dir)
      end

      # Gets backup restorer instance
      # @return [BackupRestorer] backup restorer
      def backup_restorer
        @backup_restorer ||= BackupRestorer.new(@adapter)
      end

      # Gets backup validator instance
      # @return [BackupValidator] backup validator
      def backup_validator
        @backup_validator ||= BackupValidator.new(@backup_dir)
      end
    end
  end
end
