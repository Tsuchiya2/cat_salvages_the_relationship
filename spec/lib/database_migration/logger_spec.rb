# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_migration/logger'

RSpec.describe DatabaseMigration::Logger do
  let(:mock_logger) { double('Logger') }
  let(:mock_migration_logger) { double('SemanticLogger') }

  before do
    allow(described_class).to receive(:logger).and_return(mock_logger)
    allow(SemanticLogger).to receive(:[]).with('DatabaseMigration').and_return(mock_migration_logger)
  end

  describe '.log_migration_start' do
    let(:params) do
      {
        migration_name: 'UnifyMySQL8Database',
        source_db: 'postgresql',
        target_db: 'mysql8'
      }
    end

    it 'logs migration start event' do
      expect(mock_logger).to receive(:info).with(
        hash_including(
          message: 'Migration started',
          event: 'migration_start',
          migration_name: 'UnifyMySQL8Database',
          source_db: 'postgresql',
          target_db: 'mysql8',
          timestamp: kind_of(String)
        )
      )

      expect(mock_migration_logger).to receive(:info).with(
        hash_including(
          event: 'migration_start',
          migration_name: 'UnifyMySQL8Database'
        )
      )

      described_class.log_migration_start(**params)
    end

    it 'includes additional context' do
      additional_context = { user_id: 'user-123', environment: 'production' }

      expect(mock_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      expect(mock_migration_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      described_class.log_migration_start(**params, **additional_context)
    end

    it 'includes ISO8601 timestamp' do
      expect(mock_logger).to receive(:info) do |log_data|
        expect(log_data[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      expect(mock_migration_logger).to receive(:info)

      described_class.log_migration_start(**params)
    end
  end

  describe '.log_table_migration' do
    let(:params) do
      {
        table_name: 'users',
        records_migrated: 1500,
        duration_ms: 234.56789
      }
    end

    context 'with successful migration' do
      it 'logs table migration success at info level' do
        expect(mock_logger).to receive(:info).with(
          hash_including(
            message: 'Table migration success',
            event: 'table_migration',
            table_name: 'users',
            records_migrated: 1500,
            duration_ms: 234.57,
            status: 'success',
            timestamp: kind_of(String)
          )
        )

        expect(mock_migration_logger).to receive(:info)

        described_class.log_table_migration(**params)
      end

      it 'rounds duration to 2 decimal places' do
        expect(mock_logger).to receive(:info) do |log_data|
          expect(log_data[:duration_ms]).to eq(234.57)
        end

        expect(mock_migration_logger).to receive(:info)

        described_class.log_table_migration(**params)
      end
    end

    context 'with failed migration' do
      it 'logs table migration failure at error level' do
        params[:status] = 'failed'

        expect(mock_logger).to receive(:error).with(
          hash_including(
            message: 'Table migration failed',
            status: 'failed'
          )
        )

        expect(mock_migration_logger).to receive(:error)

        described_class.log_table_migration(**params)
      end
    end

    context 'with partial migration' do
      it 'logs table migration partial at info level' do
        params[:status] = 'partial'

        expect(mock_logger).to receive(:info).with(
          hash_including(
            message: 'Table migration partial',
            status: 'partial'
          )
        )

        expect(mock_migration_logger).to receive(:info)

        described_class.log_table_migration(**params)
      end
    end

    it 'includes additional context' do
      additional_context = { error_details: 'Constraint violation' }

      expect(mock_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      expect(mock_migration_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      described_class.log_table_migration(**params, **additional_context)
    end
  end

  describe '.log_migration_error' do
    let(:error) do
      e = StandardError.new('Database connection failed')
      e.set_backtrace(['line 1', 'line 2'])
      e
    end
    let(:context) { { table_name: 'users', operation: 'insert' } }

    it 'logs migration error at error level' do
      expect(mock_logger).to receive(:error) do |log_data|
        expect(log_data[:message]).to eq('Migration error')
        expect(log_data[:event]).to eq('migration_error')
        expect(log_data[:error_class]).to eq('StandardError')
        expect(log_data[:error_message]).to eq('Database connection failed')
        expect(log_data[:backtrace]).to be_a(Array)
        expect(log_data[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      expect(mock_migration_logger).to receive(:error)

      described_class.log_migration_error(error: error, **context)
    end

    it 'includes context information' do
      expect(mock_logger).to receive(:error).with(
        hash_including(context)
      )

      expect(mock_migration_logger).to receive(:error).with(
        hash_including(context)
      )

      described_class.log_migration_error(error: error, **context)
    end

    it 'includes first 5 lines of backtrace' do
      error.set_backtrace((1..10).map { |i| "line #{i}" })

      expect(mock_logger).to receive(:error) do |log_data|
        expect(log_data[:backtrace].length).to eq(5)
        expect(log_data[:backtrace].first).to eq('line 1')
      end

      expect(mock_migration_logger).to receive(:error)

      described_class.log_migration_error(error: error, **context)
    end

    it 'handles error without backtrace' do
      error.set_backtrace(nil)

      expect(mock_logger).to receive(:error).with(
        hash_including(backtrace: nil)
      )

      expect(mock_migration_logger).to receive(:error)

      described_class.log_migration_error(error: error, **context)
    end
  end

  describe '.log_migration_progress' do
    let(:params) do
      {
        progress_percent: 45.6789,
        current_step: 'Migrating table: users'
      }
    end

    it 'logs migration progress at info level' do
      expect(mock_logger).to receive(:info).with(
        hash_including(
          message: 'Migration progress update',
          event: 'migration_progress',
          progress_percent: 45.68,
          current_step: 'Migrating table: users',
          timestamp: kind_of(String)
        )
      )

      expect(mock_migration_logger).to receive(:info)

      described_class.log_migration_progress(**params)
    end

    it 'rounds progress percent to 2 decimal places' do
      expect(mock_logger).to receive(:info) do |log_data|
        expect(log_data[:progress_percent]).to eq(45.68)
      end

      expect(mock_migration_logger).to receive(:info)

      described_class.log_migration_progress(**params)
    end

    it 'includes additional context' do
      additional_context = { tables_completed: 5, tables_total: 10 }

      expect(mock_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      expect(mock_migration_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      described_class.log_migration_progress(**params, **additional_context)
    end
  end

  describe '.log_migration_complete' do
    let(:params) do
      {
        migration_name: 'UnifyMySQL8Database',
        total_duration_ms: 3600000.123,
        total_records: 150000
      }
    end

    context 'with successful completion' do
      it 'logs migration completion at info level' do
        expect(mock_logger).to receive(:info).with(
          hash_including(
            message: 'Migration success',
            event: 'migration_complete',
            migration_name: 'UnifyMySQL8Database',
            total_duration_ms: 3600000.12,
            total_records: 150000,
            status: 'success',
            timestamp: kind_of(String)
          )
        )

        expect(mock_migration_logger).to receive(:info)

        described_class.log_migration_complete(**params)
      end

      it 'rounds total duration to 2 decimal places' do
        expect(mock_logger).to receive(:info) do |log_data|
          expect(log_data[:total_duration_ms]).to eq(3600000.12)
        end

        expect(mock_migration_logger).to receive(:info)

        described_class.log_migration_complete(**params)
      end
    end

    context 'with failed completion' do
      it 'logs migration failure at error level' do
        params[:status] = 'failed'

        expect(mock_logger).to receive(:error).with(
          hash_including(
            message: 'Migration failed',
            status: 'failed'
          )
        )

        expect(mock_migration_logger).to receive(:error)

        described_class.log_migration_complete(**params)
      end
    end

    it 'includes additional context' do
      additional_context = { tables_migrated: 25, errors_encountered: 0 }

      expect(mock_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      expect(mock_migration_logger).to receive(:info).with(
        hash_including(additional_context)
      )

      described_class.log_migration_complete(**params, **additional_context)
    end
  end

  describe 'module inclusion' do
    it 'includes SemanticLogger::Loggable' do
      expect(described_class.ancestors).to include(SemanticLogger::Loggable)
    end
  end

  describe 'private methods' do
    describe '.write_to_migration_log' do
      it 'writes to separate migration logger' do
        expect(SemanticLogger).to receive(:[]).with('DatabaseMigration').and_return(mock_migration_logger)
        expect(mock_migration_logger).to receive(:info) do |arg|
          expect(arg[:event]).to eq('test_event')
          expect(arg[:data]).to eq('test_data')
        end

        described_class.send(
          :write_to_migration_log,
          level: :info,
          event: 'test_event',
          data: 'test_data'
        )
      end

      it 'supports different log levels' do
        expect(mock_migration_logger).to receive(:error)

        described_class.send(
          :write_to_migration_log,
          level: :error,
          event: 'error_event'
        )
      end

      it 'supports warn level' do
        expect(mock_migration_logger).to receive(:warn)

        described_class.send(
          :write_to_migration_log,
          level: :warn,
          event: 'warn_event'
        )
      end
    end
  end
end
