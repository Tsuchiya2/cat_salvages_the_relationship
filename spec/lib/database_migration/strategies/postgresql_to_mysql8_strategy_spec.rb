# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../lib/database_migration/strategies/postgresql_to_mysql8_strategy'
require_relative '../../../../lib/database_adapter/mysql8_adapter'
require_relative '../../../../lib/database_adapter/postgresql_adapter'

RSpec.describe DatabaseMigration::Strategies::PostgreSQLToMySQL8Strategy do
  let(:strategy) { described_class.new }
  let(:pg_adapter) { DatabaseAdapter::PostgreSQLAdapter.new }
  let(:mysql_adapter) { DatabaseAdapter::MySQL8Adapter.new }

  describe '#initialize' do
    it 'initializes with default migration tool' do
      expect(strategy.migration_tool).to eq(:pgloader)
    end

    it 'allows custom migration tool' do
      custom_strategy = described_class.new(tool: :custom_etl)
      expect(custom_strategy.migration_tool).to eq(:custom_etl)
    end

    it 'sets default parallel workers to 8' do
      expect(strategy.instance_variable_get(:@parallel_workers)).to eq(8)
    end

    it 'allows custom parallel workers' do
      custom_strategy = described_class.new(parallel_workers: 16)
      expect(custom_strategy.instance_variable_get(:@parallel_workers)).to eq(16)
    end
  end

  describe '#prepare' do
    context 'with valid adapters' do
      before do
        allow(pg_adapter).to receive(:adapter_name).and_return('postgresql')
        allow(mysql_adapter).to receive(:adapter_name).and_return('mysql2')
        allow(strategy).to receive(:create_backup).and_return({ status: 'backup_ready' })
        allow(strategy).to receive(:verify_target_empty).and_return({ status: 'verified' })
        allow(strategy).to receive(:generate_migration_config).and_return({ status: 'config_generated' })
      end

      it 'returns preparation results' do
        result = strategy.prepare(pg_adapter, mysql_adapter)

        expect(result).to be_a(Hash)
        expect(result[:backup]).to eq({ status: 'backup_ready' })
        expect(result[:target_verified]).to eq({ status: 'verified' })
        expect(result[:config_generated]).to eq({ status: 'config_generated' })
      end

      it 'calls create_backup with source adapter' do
        expect(strategy).to receive(:create_backup).with(pg_adapter)
        strategy.prepare(pg_adapter, mysql_adapter)
      end

      it 'calls verify_target_empty with target adapter' do
        expect(strategy).to receive(:verify_target_empty).with(mysql_adapter)
        strategy.prepare(pg_adapter, mysql_adapter)
      end

      it 'calls generate_migration_config' do
        expect(strategy).to receive(:generate_migration_config)
        strategy.prepare(pg_adapter, mysql_adapter)
      end
    end

    context 'with invalid source adapter' do
      let(:invalid_adapter) { instance_double('DatabaseAdapter::Base', adapter_name: 'mysql2') }

      it 'raises ArgumentError' do
        expect { strategy.prepare(invalid_adapter, mysql_adapter) }.to raise_error(
          ArgumentError,
          'Source must be PostgreSQL, got mysql2'
        )
      end
    end

    context 'with invalid target adapter' do
      let(:invalid_adapter) { instance_double('DatabaseAdapter::Base', adapter_name: 'postgresql') }

      it 'raises ArgumentError' do
        expect { strategy.prepare(pg_adapter, invalid_adapter) }.to raise_error(
          ArgumentError,
          'Target must be MySQL 8, got postgresql'
        )
      end
    end
  end

  describe '#migrate' do
    before do
      allow(pg_adapter).to receive(:adapter_name).and_return('postgresql')
      allow(mysql_adapter).to receive(:adapter_name).and_return('mysql2')
    end

    context 'with pgloader tool' do
      it 'executes pgloader migration' do
        result = strategy.migrate(pg_adapter, mysql_adapter)

        expect(result[:status]).to eq('migration_completed')
        expect(result[:tool]).to eq('pgloader')
      end
    end

    context 'with custom_etl tool' do
      let(:strategy) { described_class.new(tool: :custom_etl) }

      it 'executes custom ETL migration' do
        result = strategy.migrate(pg_adapter, mysql_adapter)

        expect(result[:status]).to eq('migration_completed')
        expect(result[:tool]).to eq('custom_etl')
      end
    end

    context 'with dump_and_load tool' do
      let(:strategy) { described_class.new(tool: :dump_and_load) }

      it 'executes dump and load migration' do
        result = strategy.migrate(pg_adapter, mysql_adapter)

        expect(result[:status]).to eq('migration_completed')
        expect(result[:tool]).to eq('dump_and_load')
      end
    end

    context 'with unknown tool' do
      let(:strategy) { described_class.new(tool: :unknown_tool) }

      it 'raises an error' do
        expect { strategy.migrate(pg_adapter, mysql_adapter) }.to raise_error(
          'Unknown migration tool: unknown_tool'
        )
      end
    end
  end

  describe '#cleanup' do
    let(:temp_dir) { 'tmp' }

    before do
      FileUtils.mkdir_p(temp_dir)
    end

    after do
      FileUtils.rm_rf(temp_dir)
      File.delete('migration.load') if File.exist?('migration.load')
    end

    context 'when cleanup is successful' do
      before do
        File.write('migration.load', 'test config')
        File.write('tmp/migration_test1.tmp', 'temp data 1')
        File.write('tmp/migration_test2.tmp', 'temp data 2')
      end

      it 'removes pgloader config file' do
        strategy.cleanup

        expect(File.exist?('migration.load')).to be false
      end

      it 'removes temporary migration files' do
        strategy.cleanup

        expect(File.exist?('tmp/migration_test1.tmp')).to be false
        expect(File.exist?('tmp/migration_test2.tmp')).to be false
      end

      it 'returns cleanup result with removed files' do
        result = strategy.cleanup

        expect(result[:status]).to eq('cleanup_complete')
        expect(result[:files_removed]).to include('migration.load')
        expect(result[:files_removed]).to include('tmp/migration_test1.tmp')
        expect(result[:files_removed]).to include('tmp/migration_test2.tmp')
        expect(result[:timestamp]).to be_present
      end
    end

    context 'when no files to clean up' do
      it 'returns empty cleanup result' do
        result = strategy.cleanup

        expect(result[:status]).to eq('cleanup_complete')
        expect(result[:files_removed]).to be_empty
      end
    end

    context 'when cleanup fails' do
      before do
        allow(Dir).to receive(:glob).and_raise(StandardError.new('Filesystem error'))
      end

      it 'returns cleanup failed status' do
        result = strategy.cleanup

        expect(result[:status]).to eq('cleanup_failed')
        expect(result[:error]).to eq('Filesystem error')
      end
    end
  end

  describe '#estimated_duration' do
    it 'returns estimated duration in seconds' do
      expect(strategy.estimated_duration).to eq(1800)
    end
  end

  describe '#generate_pgloader_config' do
    let(:strategy) { described_class.new(parallel_workers: 12) }

    before do
      ENV['PG_USER'] = 'pguser'
      ENV['PG_PASSWORD'] = 'pgpass'
      ENV['PG_HOST'] = 'pghost'
      ENV['PG_DATABASE'] = 'pgdb'
      ENV['DB_USERNAME'] = 'mysqluser'
      ENV['DB_PASSWORD'] = 'mysqlpass'
      ENV['DB_HOST'] = 'mysqlhost'
      ENV['DB_NAME'] = 'mysqldb'
    end

    after do
      File.delete('migration.load') if File.exist?('migration.load')
      ENV.delete('PG_USER')
      ENV.delete('PG_PASSWORD')
      ENV.delete('PG_HOST')
      ENV.delete('PG_DATABASE')
      ENV.delete('DB_USERNAME')
      ENV.delete('DB_PASSWORD')
      ENV.delete('DB_HOST')
      ENV.delete('DB_NAME')
    end

    it 'generates pgloader configuration file' do
      result = strategy.send(:generate_pgloader_config)

      expect(result[:status]).to eq('config_generated')
      expect(result[:file]).to eq('migration.load')
      expect(result[:workers]).to eq(12)
      expect(File.exist?('migration.load')).to be true
    end

    it 'includes correct connection strings in config' do
      strategy.send(:generate_pgloader_config)

      config_content = File.read('migration.load')
      expect(config_content).to include('FROM postgresql://pguser:pgpass@pghost/pgdb')
      expect(config_content).to include('INTO mysql://mysqluser:mysqlpass@mysqlhost/mysqldb')
    end

    it 'includes parallel workers configuration' do
      strategy.send(:generate_pgloader_config)

      config_content = File.read('migration.load')
      expect(config_content).to include('workers = 12')
    end

    it 'includes datetime casting rules' do
      strategy.send(:generate_pgloader_config)

      config_content = File.read('migration.load')
      expect(config_content).to include('CAST type datetime')
      expect(config_content).to include('type timestamp')
    end

    context 'when file write fails' do
      before do
        allow(File).to receive(:write).and_raise(StandardError.new('Write error'))
      end

      it 'returns config generation failed status' do
        result = strategy.send(:generate_pgloader_config)

        expect(result[:status]).to eq('config_generation_failed')
        expect(result[:error]).to eq('Write error')
      end
    end
  end

  describe '#create_backup' do
    it 'sets backup_created flag' do
      result = strategy.send(:create_backup, pg_adapter)

      expect(result[:status]).to eq('backup_ready')
      expect(strategy.instance_variable_get(:@backup_created)).to be true
    end

    it 'returns backup result with note' do
      result = strategy.send(:create_backup, pg_adapter)

      expect(result[:note]).to include('Backup service integration pending')
    end
  end

  describe '#verify_target_empty' do
    it 'returns verification result' do
      result = strategy.send(:verify_target_empty, mysql_adapter)

      expect(result[:status]).to eq('verified')
      expect(result[:note]).to include('Target verification will use ActiveRecord')
    end
  end

  describe '#log_preparation' do
    let(:results) do
      {
        backup: { status: 'backup_ready' },
        target_verified: { status: 'verified' },
        config_generated: { status: 'config_generated' }
      }
    end

    context 'when Rails is defined' do
      let(:mock_logger) { double('Logger', info: nil) }

      before do
        stub_const('Rails', double('Rails', logger: mock_logger))
      end

      it 'logs preparation results' do
        expect(mock_logger).to receive(:info).with(
          hash_including(
            message: 'Migration preparation completed',
            backup_status: 'backup_ready',
            target_verified: 'verified',
            config_generated: 'config_generated'
          )
        )

        strategy.send(:log_preparation, results)
      end
    end

    context 'when Rails is not defined' do
      it 'does not raise an error' do
        expect { strategy.send(:log_preparation, results) }.not_to raise_error
      end
    end
  end
end
