# frozen_string_literal: true

module DatabaseMigration
  module Services
    # Backup validation service
    # Handles listing and validating database backups
    class BackupValidator
      attr_reader :backup_dir

      # Initializes the backup validator
      # @param backup_dir [String] backup directory path
      def initialize(backup_dir)
        @backup_dir = backup_dir
      end

      # Lists available backup files
      # @return [Array<Hash>] list of backup files with metadata
      def list_backups
        return [] unless Dir.exist?(@backup_dir)

        Dir.glob(File.join(@backup_dir, '*.sql')).map do |file|
          {
            file: file,
            size: File.size(file),
            created_at: File.mtime(file),
            adapter: extract_adapter_from_filename(file)
          }
        end.sort_by { |b| b[:created_at] }.reverse
      end

      private

      # Extracts adapter name from backup filename
      # @param filename [String] backup filename
      # @return [String, nil] adapter name or nil
      def extract_adapter_from_filename(filename)
        case File.basename(filename)
        when /postgresql/
          'postgresql'
        when /mysql/
          'mysql2'
        end
      end
    end
  end
end
