# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_migration/migration_config'

RSpec.describe DatabaseMigration::MigrationConfig do
  let(:config_file_path) { Rails.root.join(described_class::CONFIG_FILE) }
  let(:config_dir) { File.dirname(config_file_path) }

  before do
    FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
  end

  after do
    File.delete(config_file_path) if File.exist?(config_file_path)
  end

  describe '#initialize' do
    context 'with configuration file' do
      let(:config_yaml) do
        {
          'test' => {
            'migration' => {
              'tool' => 'custom_etl',
              'parallel_workers' => 16,
              'verification' => {
                'row_count_threshold' => 100,
                'retry_attempts' => 5,
                'enable_checksum' => true
              },
              'performance' => {
                'target_downtime_minutes' => 60,
                'query_timeout_ms' => 10000
              }
            }
          }
        }
      end

      before do
        File.write(config_file_path, config_yaml.to_yaml)
      end

      it 'loads configuration from YAML file' do
        config = described_class.new

        expect(config.migration_tool).to eq('custom_etl')
        expect(config.parallel_workers).to eq(16)
      end

      it 'symbolizes keys in configuration' do
        config = described_class.new

        expect(config.config).to be_a(Hash)
        expect(config.config.keys.first).to be_a(Symbol)
      end
    end

    context 'with default environment configuration' do
      let(:config_yaml) do
        {
          'default' => {
            'migration' => {
              'tool' => 'pgloader',
              'parallel_workers' => 8
            }
          }
        }
      end

      before do
        File.write(config_file_path, config_yaml.to_yaml)
      end

      it 'uses default configuration when environment-specific config is not available' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('staging'))
        config = described_class.new

        expect(config.migration_tool).to eq('pgloader')
        expect(config.parallel_workers).to eq(8)
      end
    end

    context 'without configuration file' do
      it 'uses default configuration' do
        config = described_class.new

        expect(config.migration_tool).to eq('pgloader')
        expect(config.parallel_workers).to eq(8)
      end
    end

    context 'with configuration overrides' do
      it 'merges overrides with loaded configuration' do
        overrides = { migration: { tool: 'dump_and_load', parallel_workers: 4 } }
        config = described_class.new(overrides)

        expect(config.migration_tool).to eq('dump_and_load')
        expect(config.parallel_workers).to eq(4)
      end

      it 'deep merges nested configuration' do
        File.write(config_file_path, {
          'test' => {
            'migration' => {
              'tool' => 'pgloader',
              'verification' => {
                'retry_attempts' => 3
              }
            }
          }
        }.to_yaml)

        overrides = { migration: { verification: { enable_checksum: true } } }
        config = described_class.new(overrides)

        expect(config.retry_attempts).to eq(3)
        expect(config.enable_checksum?).to be true
      end
    end

    context 'when YAML loading fails' do
      before do
        File.write(config_file_path, 'invalid: yaml: content: [')
        allow(Rails).to receive(:logger).and_return(double('Logger', warn: nil))
      end

      it 'falls back to default configuration' do
        config = described_class.new

        expect(config.migration_tool).to eq('pgloader')
        expect(config.parallel_workers).to eq(8)
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/Failed to load migration config/)

        described_class.new
      end
    end
  end

  describe '#migration_tool' do
    it 'returns migration tool from config' do
      config = described_class.new({ migration: { tool: 'custom_etl' } })

      expect(config.migration_tool).to eq('custom_etl')
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.migration_tool).to eq('pgloader')
    end
  end

  describe '#parallel_workers' do
    it 'returns parallel workers from config' do
      config = described_class.new({ migration: { parallel_workers: 16 } })

      expect(config.parallel_workers).to eq(16)
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.parallel_workers).to eq(8)
    end
  end

  describe '#verification_threshold' do
    it 'returns verification threshold from config' do
      config = described_class.new({ migration: { verification: { row_count_threshold: 100 } } })

      expect(config.verification_threshold).to eq(100)
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.verification_threshold).to eq(0)
    end
  end

  describe '#retry_attempts' do
    it 'returns retry attempts from config' do
      config = described_class.new({ migration: { verification: { retry_attempts: 5 } } })

      expect(config.retry_attempts).to eq(5)
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.retry_attempts).to eq(3)
    end
  end

  describe '#target_downtime_minutes' do
    it 'returns target downtime from config' do
      config = described_class.new({ migration: { performance: { target_downtime_minutes: 60 } } })

      expect(config.target_downtime_minutes).to eq(60)
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.target_downtime_minutes).to eq(30)
    end
  end

  describe '#query_timeout_ms' do
    it 'returns query timeout from config' do
      config = described_class.new({ migration: { performance: { query_timeout_ms: 10000 } } })

      expect(config.query_timeout_ms).to eq(10000)
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.query_timeout_ms).to eq(5000)
    end
  end

  describe '#enable_checksum?' do
    it 'returns true when checksum is enabled' do
      config = described_class.new({ migration: { verification: { enable_checksum: true } } })

      expect(config.enable_checksum?).to be true
    end

    it 'returns false when checksum is disabled' do
      config = described_class.new({ migration: { verification: { enable_checksum: false } } })

      expect(config.enable_checksum?).to be false
    end

    it 'returns default value when not configured' do
      config = described_class.new

      expect(config.enable_checksum?).to be false
    end
  end

  describe '#to_h' do
    it 'returns configuration as hash' do
      config = described_class.new({ migration: { tool: 'pgloader' } })

      result = config.to_h

      expect(result).to be_a(Hash)
      expect(result[:migration][:tool]).to eq('pgloader')
    end
  end

  describe 'environment variable defaults' do
    before do
      ENV['DB_MIGRATION_TOOL'] = 'custom_tool'
      ENV['DB_MIGRATION_WORKERS'] = '12'
      ENV['DB_MIGRATION_ROW_COUNT_THRESHOLD'] = '50'
      ENV['DB_MIGRATION_RETRY_ATTEMPTS'] = '7'
      ENV['DB_MIGRATION_ENABLE_CHECKSUM'] = 'true'
      ENV['DB_MIGRATION_TARGET_DOWNTIME'] = '45'
      ENV['DB_MIGRATION_QUERY_TIMEOUT'] = '8000'
    end

    after do
      ENV.delete('DB_MIGRATION_TOOL')
      ENV.delete('DB_MIGRATION_WORKERS')
      ENV.delete('DB_MIGRATION_ROW_COUNT_THRESHOLD')
      ENV.delete('DB_MIGRATION_RETRY_ATTEMPTS')
      ENV.delete('DB_MIGRATION_ENABLE_CHECKSUM')
      ENV.delete('DB_MIGRATION_TARGET_DOWNTIME')
      ENV.delete('DB_MIGRATION_QUERY_TIMEOUT')
    end

    it 'uses environment variables when config file is not present' do
      config = described_class.new

      expect(config.migration_tool).to eq('custom_tool')
      expect(config.parallel_workers).to eq(12)
      expect(config.verification_threshold).to eq(50)
      expect(config.retry_attempts).to eq(7)
      expect(config.enable_checksum?).to be true
      expect(config.target_downtime_minutes).to eq(45)
      expect(config.query_timeout_ms).to eq(8000)
    end
  end

  describe 'key symbolization' do
    it 'converts string keys to symbols' do
      hash = { 'migration' => { 'tool' => 'pgloader' } }
      config = described_class.new

      symbolized = config.send(:symbolize_keys, hash)

      expect(symbolized.keys.first).to eq(:migration)
      expect(symbolized[:migration].keys.first).to eq(:tool)
    end

    it 'recursively symbolizes nested hashes' do
      hash = {
        'migration' => {
          'verification' => {
            'enable_checksum' => true
          }
        }
      }
      config = described_class.new

      symbolized = config.send(:symbolize_keys, hash)

      expect(symbolized[:migration][:verification][:enable_checksum]).to be true
    end

    it 'handles non-hash values' do
      config = described_class.new

      expect(config.send(:symbolize_keys, 'string')).to eq('string')
      expect(config.send(:symbolize_keys, 123)).to eq(123)
      expect(config.send(:symbolize_keys, nil)).to be_nil
    end
  end
end
