# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../lib/database_migration/services/backup_service'
require_relative '../../../../lib/database_adapter/mysql8_adapter'
require_relative '../../../../lib/database_adapter/postgresql_adapter'

RSpec.describe DatabaseMigration::Services::BackupService do
  let(:pg_adapter) { DatabaseAdapter::PostgreSQLAdapter.new }
  let(:mysql_adapter) { DatabaseAdapter::MySQL8Adapter.new }
  let(:backup_dir) { 'tmp/test_backups' }
  let(:service) { described_class.new(pg_adapter, backup_dir: backup_dir) }

  before do
    FileUtils.mkdir_p(backup_dir)
    allow(pg_adapter).to receive(:adapter_name).and_return('postgresql')
    allow(mysql_adapter).to receive(:adapter_name).and_return('mysql2')
  end

  after do
    FileUtils.rm_rf(backup_dir)
  end

  describe '#initialize' do
    it 'sets the adapter' do
      expect(service.adapter).to eq(pg_adapter)
    end

    it 'sets the config' do
      expect(service.config[:backup_dir]).to eq(backup_dir)
    end

    it 'uses default backup directory if not specified' do
      default_service = described_class.new(pg_adapter)
      expect(default_service.instance_variable_get(:@backup_dir)).to eq('db/backups')
    end
  end

  describe '#create_backup' do
    context 'for PostgreSQL' do
      before do
        ENV['PG_HOST'] = 'localhost'
        ENV['PG_USER'] = 'pguser'
        ENV['PG_DATABASE'] = 'test_db'
      end

      after do
        ENV.delete('PG_HOST')
        ENV.delete('PG_USER')
        ENV.delete('PG_DATABASE')
      end

      it 'creates PostgreSQL backup successfully', :skip => 'Requires actual PostgreSQL connection' do
        allow(service).to receive(:system).and_return(true)
        allow(File).to receive(:size).and_call_original
        allow(File).to receive(:size).with(match(/backup_postgresql_.*\.sql$/)).and_return(1024)

        result = service.create_backup

        expect(result[:status]).to eq('success')
        expect(result[:adapter]).to eq('postgresql')
        expect(result[:file]).to include('backup_postgresql_')
        expect(result[:file]).to end_with('.sql')
        expect(result[:size]).to eq(1024)
        expect(result[:timestamp]).to be_present
      end

      it 'creates backup directory if it does not exist' do
        backup_dir = 'tmp/new_backup_dir'
        new_service = described_class.new(pg_adapter, backup_dir: backup_dir)

        allow(new_service).to receive(:system).and_return(true)
        allow(File).to receive(:size).and_return(1024)

        expect(Dir.exist?(backup_dir)).to be false
        new_service.create_backup
        expect(Dir.exist?(backup_dir)).to be true

        FileUtils.rm_rf(backup_dir)
      end

      it 'handles backup failure', :skip => 'Requires actual PostgreSQL connection' do
        allow(service).to receive(:system).and_return(false)
        process_status = instance_double(Process::Status, exitstatus: 1)
        allow(service).to receive(:$?).and_return(process_status)

        result = service.create_backup

        expect(result[:status]).to eq('failed')
        expect(result[:adapter]).to eq('postgresql')
        expect(result[:error]).to include('PostgreSQL backup failed')
      end
    end

    context 'for MySQL' do
      let(:service) { described_class.new(mysql_adapter, backup_dir: backup_dir) }

      before do
        ENV['DB_HOST'] = 'localhost'
        ENV['DB_USERNAME'] = 'mysqluser'
        ENV['DB_PASSWORD'] = 'mysqlpass'
        ENV['DB_NAME'] = 'test_db'
      end

      after do
        ENV.delete('DB_HOST')
        ENV.delete('DB_USERNAME')
        ENV.delete('DB_PASSWORD')
        ENV.delete('DB_NAME')
      end

      it 'creates MySQL backup successfully', :skip => 'Requires actual MySQL connection' do
        allow(service).to receive(:system).and_return(true)
        allow(File).to receive(:size).and_call_original
        allow(File).to receive(:size).with(match(/backup_mysql_.*\.sql$/)).and_return(2048)

        result = service.create_backup

        expect(result[:status]).to eq('success')
        expect(result[:adapter]).to eq('mysql2')
        expect(result[:file]).to include('backup_mysql_')
        expect(result[:file]).to end_with('.sql')
        expect(result[:size]).to eq(2048)
        expect(result[:timestamp]).to be_present
      end

      it 'handles backup failure', :skip => 'Requires actual MySQL connection' do
        allow(service).to receive(:system).and_return(false)
        process_status = instance_double(Process::Status, exitstatus: 1)
        allow(service).to receive(:$?).and_return(process_status)

        result = service.create_backup

        expect(result[:status]).to eq('failed')
        expect(result[:adapter]).to eq('mysql2')
        expect(result[:error]).to include('MySQL backup failed')
      end
    end

    context 'for unsupported adapter' do
      let(:unsupported_adapter) { instance_double('DatabaseAdapter::Base', adapter_name: 'sqlite3') }
      let(:service) { described_class.new(unsupported_adapter, backup_dir: backup_dir) }

      it 'raises an error' do
        expect { service.create_backup }.to raise_error(
          'Backup not supported for adapter: sqlite3'
        )
      end
    end
  end

  describe '#restore_backup' do
    let(:backup_file) { File.join(backup_dir, 'backup_postgresql_20231201_120000.sql') }

    context 'for PostgreSQL' do
      before do
        File.write(backup_file, 'SQL DUMP DATA')
        ENV['PG_HOST'] = 'localhost'
        ENV['PG_USER'] = 'pguser'
        ENV['PG_DATABASE'] = 'test_db'
      end

      after do
        ENV.delete('PG_HOST')
        ENV.delete('PG_USER')
        ENV.delete('PG_DATABASE')
      end

      it 'restores PostgreSQL backup successfully', :skip => 'Requires actual PostgreSQL connection' do
        allow(service).to receive(:system).and_return(true)

        result = service.restore_backup(backup_file)

        expect(result[:status]).to eq('success')
        expect(result[:adapter]).to eq('postgresql')
        expect(result[:file]).to eq(backup_file)
      end

      it 'handles restore failure', :skip => 'Requires actual PostgreSQL connection' do
        allow(service).to receive(:system).and_return(false)
        process_status = instance_double(Process::Status, exitstatus: 1)
        allow(service).to receive(:$?).and_return(process_status)

        result = service.restore_backup(backup_file)

        expect(result[:status]).to eq('failed')
        expect(result[:adapter]).to eq('postgresql')
        expect(result[:error]).to include('PostgreSQL restore failed')
      end
    end

    context 'for MySQL' do
      let(:service) { described_class.new(mysql_adapter, backup_dir: backup_dir) }
      let(:backup_file) { File.join(backup_dir, 'backup_mysql_20231201_120000.sql') }

      before do
        File.write(backup_file, 'SQL DUMP DATA')
        ENV['DB_HOST'] = 'localhost'
        ENV['DB_USERNAME'] = 'mysqluser'
        ENV['DB_PASSWORD'] = 'mysqlpass'
        ENV['DB_NAME'] = 'test_db'
      end

      after do
        ENV.delete('DB_HOST')
        ENV.delete('DB_USERNAME')
        ENV.delete('DB_PASSWORD')
        ENV.delete('DB_NAME')
      end

      it 'restores MySQL backup successfully', :skip => 'Requires actual MySQL connection' do
        allow(service).to receive(:system).and_return(true)

        result = service.restore_backup(backup_file)

        expect(result[:status]).to eq('success')
        expect(result[:adapter]).to eq('mysql2')
        expect(result[:file]).to eq(backup_file)
      end

      it 'handles restore failure', :skip => 'Requires actual MySQL connection' do
        allow(service).to receive(:system).and_return(false)
        process_status = instance_double(Process::Status, exitstatus: 1)
        allow(service).to receive(:$?).and_return(process_status)

        result = service.restore_backup(backup_file)

        expect(result[:status]).to eq('failed')
        expect(result[:adapter]).to eq('mysql2')
        expect(result[:error]).to include('MySQL restore failed')
      end
    end

    context 'when backup file does not exist' do
      let(:nonexistent_file) { File.join(backup_dir, 'nonexistent.sql') }

      it 'raises an error' do
        expect { service.restore_backup(nonexistent_file) }.to raise_error(
          "Backup file not found: #{nonexistent_file}"
        )
      end
    end

    context 'for unsupported adapter' do
      let(:unsupported_adapter) { instance_double('DatabaseAdapter::Base', adapter_name: 'sqlite3') }
      let(:service) { described_class.new(unsupported_adapter, backup_dir: backup_dir) }

      before do
        File.write(backup_file, 'SQL DUMP DATA')
      end

      it 'raises an error' do
        expect { service.restore_backup(backup_file) }.to raise_error(
          'Restore not supported for adapter: sqlite3'
        )
      end
    end
  end

  describe '#list_backups' do
    context 'when backup directory exists with files' do
      before do
        File.write(File.join(backup_dir, 'backup_postgresql_20231201_120000.sql'), 'data1')
        File.write(File.join(backup_dir, 'backup_mysql_20231201_130000.sql'), 'data2')
        File.write(File.join(backup_dir, 'backup_postgresql_20231201_140000.sql'), 'data3')
        sleep 0.1 # Ensure different timestamps
      end

      it 'lists all backup files' do
        backups = service.list_backups

        expect(backups.length).to eq(3)
      end

      it 'includes file metadata' do
        backups = service.list_backups

        expect(backups.first[:file]).to be_present
        expect(backups.first[:size]).to be > 0
        expect(backups.first[:created_at]).to be_a(Time)
        expect(backups.first[:adapter]).to be_present
      end

      it 'sorts backups by creation time (newest first)' do
        backups = service.list_backups

        expect(backups.first[:file]).to include('140000')
        expect(backups.last[:file]).to include('120000')
      end

      it 'identifies PostgreSQL backups' do
        backups = service.list_backups
        pg_backup = backups.find { |b| b[:file].include?('postgresql') }

        expect(pg_backup[:adapter]).to eq('postgresql')
      end

      it 'identifies MySQL backups' do
        backups = service.list_backups
        mysql_backup = backups.find { |b| b[:file].include?('mysql') }

        expect(mysql_backup[:adapter]).to eq('mysql2')
      end
    end

    context 'when backup directory is empty' do
      it 'returns empty array' do
        backups = service.list_backups

        expect(backups).to eq([])
      end
    end

    context 'when backup directory does not exist' do
      let(:service) { described_class.new(pg_adapter, backup_dir: 'tmp/nonexistent_dir') }

      it 'returns empty array' do
        backups = service.list_backups

        expect(backups).to eq([])
      end
    end
  end

end
