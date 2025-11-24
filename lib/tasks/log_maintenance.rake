# frozen_string_literal: true

namespace :logs do
  desc 'Clean up old log files based on retention policy'
  task cleanup: :environment do
    require 'yaml'

    config_file = Rails.root.join('config', 'logging.yml')
    unless File.exist?(config_file)
      puts 'logging.yml not found, skipping cleanup'
      next
    end

    config = YAML.load_file(config_file)
    retention_days = config.dig('rotation', 'retention_days') || 30
    cutoff_date = retention_days.days.ago

    puts "Cleaning up log files older than #{retention_days} days (before #{cutoff_date.to_date})"

    log_patterns = [
      Rails.root.join('log', '*.log.*'),
      Rails.root.join('log', '*.log.*.gz')
    ]

    total_deleted = 0
    total_size_freed = 0

    log_patterns.each do |pattern|
      Dir.glob(pattern).each do |file_path|
        next unless File.file?(file_path)

        file_mtime = File.mtime(file_path)
        next unless file_mtime < cutoff_date

        file_size = File.size(file_path)
        File.delete(file_path)
        total_deleted += 1
        total_size_freed += file_size

        puts "  Deleted: #{File.basename(file_path)} (#{(file_size / 1024.0 / 1024.0).round(2)} MB)"
      end
    end

    puts "Cleanup complete: #{total_deleted} files deleted, #{(total_size_freed / 1024.0 / 1024.0).round(2)} MB freed"
  end

  desc 'Rotate current log files'
  task rotate: :environment do
    require 'yaml'

    config_file = Rails.root.join('config', 'logging.yml')
    unless File.exist?(config_file)
      puts 'logging.yml not found, skipping rotation'
      next
    end

    config = YAML.load_file(config_file)
    max_size_mb = config.dig('rotation', 'max_file_size_mb') || 100
    max_size_bytes = max_size_mb * 1024 * 1024

    log_files = [
      Rails.root.join('log', 'production.log'),
      Rails.root.join('log', 'development.log'),
      Rails.root.join('log', 'test.log'),
      Rails.root.join('log', 'migration.log')
    ]

    rotated_count = 0

    log_files.each do |log_file|
      next unless File.exist?(log_file)
      next unless File.size(log_file) > max_size_bytes

      timestamp = Time.current.strftime('%Y%m%d%H%M%S')
      rotated_file = "#{log_file}.#{timestamp}"

      File.rename(log_file, rotated_file)
      File.open(log_file, 'w') {} # Create new empty log file

      puts "  Rotated: #{File.basename(log_file)} -> #{File.basename(rotated_file)}"
      rotated_count += 1

      # Optionally compress the rotated file
      if system("gzip #{rotated_file}")
        puts "  Compressed: #{File.basename(rotated_file)}.gz"
      end
    end

    if rotated_count.zero?
      puts 'No log files needed rotation'
    else
      puts "Rotation complete: #{rotated_count} files rotated"
    end
  end

  desc 'Display log file sizes and rotation status'
  task status: :environment do
    require 'yaml'

    config_file = Rails.root.join('config', 'logging.yml')
    unless File.exist?(config_file)
      puts 'logging.yml not found'
      next
    end

    config = YAML.load_file(config_file)
    max_size_mb = config.dig('rotation', 'max_file_size_mb') || 100

    puts 'Log File Status:'
    puts '=' * 80

    log_files = [
      Rails.root.join('log', 'production.log'),
      Rails.root.join('log', 'development.log'),
      Rails.root.join('log', 'test.log'),
      Rails.root.join('log', 'migration.log')
    ]

    log_files.each do |log_file|
      if File.exist?(log_file)
        size_mb = (File.size(log_file) / 1024.0 / 1024.0).round(2)
        usage_percent = ((size_mb / max_size_mb) * 100).round(1)
        status = size_mb >= max_size_mb ? 'NEEDS ROTATION' : 'OK'

        puts format('%-25s: %8.2f MB / %3d MB (%5.1f%%) [%s]',
                    File.basename(log_file), size_mb, max_size_mb, usage_percent, status)
      else
        puts format('%-25s: NOT FOUND', File.basename(log_file))
      end
    end

    # Count rotated files
    rotated_count = Dir.glob(Rails.root.join('log', '*.log.*')).count
    puts
    puts "Rotated log files: #{rotated_count}"
  end
end
