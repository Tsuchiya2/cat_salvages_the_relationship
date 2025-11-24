# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_adapter/postgresql_adapter'

RSpec.describe DatabaseAdapter::PostgreSQLAdapter do
  let(:adapter) { described_class.new }

  describe '#adapter_name' do
    it 'returns postgresql' do
      expect(adapter.adapter_name).to eq('postgresql')
    end
  end

  describe '#connection_params' do
    it 'returns PostgreSQL connection parameters' do
      params = adapter.connection_params

      expect(params[:adapter]).to eq('postgresql')
      expect(params[:encoding]).to eq('unicode')
      expect(params[:pool]).to be_a(Integer)
      expect(params[:timeout]).to eq(5000)
    end

    it 'merges custom configuration' do
      custom_adapter = described_class.new(database: 'custom_db', host: 'custom_host')
      params = custom_adapter.connection_params

      expect(params[:database]).to eq('custom_db')
      expect(params[:host]).to eq('custom_host')
    end

    it 'uses RAILS_MAX_THREADS for pool size' do
      ENV['RAILS_MAX_THREADS'] = '10'
      params = adapter.connection_params

      expect(params[:pool]).to eq(10)

      ENV.delete('RAILS_MAX_THREADS')
    end

    it 'defaults to pool size of 5 when RAILS_MAX_THREADS is not set' do
      params = adapter.connection_params

      expect(params[:pool]).to eq(5)
    end
  end

  describe '#migrate_from' do
    let(:source_adapter) { instance_double('DatabaseAdapter::Base') }

    it 'raises an error when PostgreSQL is used as migration target' do
      expect {
        adapter.migrate_from(source_adapter)
      }.to raise_error('PostgreSQL cannot be used as a migration target from itself')
    end
  end

  describe '#verify_compatibility' do
    context 'when all checks pass' do
      before do
        allow(adapter).to receive(:version_supported?).and_return(true)
        allow(adapter).to receive(:encoding_compatible?).and_return(true)
      end

      it 'returns successful checks' do
        result = adapter.verify_compatibility

        expect(result[:version_check]).to be true
        expect(result[:encoding_check]).to be true
      end

      it 'does not raise an error' do
        expect { adapter.verify_compatibility }.not_to raise_error
      end
    end

    context 'when version check fails' do
      before do
        allow(adapter).to receive(:version_supported?).and_return(false)
        allow(adapter).to receive(:encoding_compatible?).and_return(true)
      end

      it 'raises CompatibilityError' do
        expect {
          adapter.verify_compatibility
        }.to raise_error(DatabaseAdapter::CompatibilityError, /Compatibility checks failed/)
      end
    end

    context 'when encoding check fails' do
      before do
        allow(adapter).to receive(:version_supported?).and_return(true)
        allow(adapter).to receive(:encoding_compatible?).and_return(false)
      end

      it 'raises CompatibilityError' do
        expect {
          adapter.verify_compatibility
        }.to raise_error(DatabaseAdapter::CompatibilityError, /Compatibility checks failed/)
      end
    end

    context 'when multiple checks fail' do
      before do
        allow(adapter).to receive(:version_supported?).and_return(false)
        allow(adapter).to receive(:encoding_compatible?).and_return(false)
      end

      it 'raises CompatibilityError' do
        expect {
          adapter.verify_compatibility
        }.to raise_error(DatabaseAdapter::CompatibilityError)
      end
    end
  end

  describe '#version_info' do
    before do
      allow(adapter).to receive(:database_version).and_return('14.5')
      allow(adapter).to receive(:version_supported?).and_return(true)
    end

    it 'returns version information' do
      info = adapter.version_info

      expect(info[:adapter]).to eq('postgresql')
      expect(info[:version]).to eq('14.5')
      expect(info[:supported]).to be true
    end
  end

  describe '#database_version' do
    context 'when ActiveRecord is defined' do
      let(:mock_connection) { instance_double('ActiveRecord::ConnectionAdapters::PostgreSQLAdapter') }
      let(:mock_base) { double('ActiveRecord::Base') }

      before do
        stub_const('ActiveRecord::Base', mock_base)
        allow(mock_base).to receive(:connection).and_return(mock_connection)
      end

      it 'extracts version from PostgreSQL version string' do
        version_string = 'PostgreSQL 14.5 on x86_64-pc-linux-gnu, compiled by gcc'
        allow(mock_connection).to receive(:select_value).with('SELECT VERSION()').and_return(version_string)

        version = adapter.send(:database_version)

        expect(version).to eq('14.5')
      end

      it 'handles different version formats' do
        version_string = 'PostgreSQL 12.10 (Ubuntu 12.10-1.pgdg20.04+1) on x86_64-pc-linux-gnu'
        allow(mock_connection).to receive(:select_value).with('SELECT VERSION()').and_return(version_string)

        version = adapter.send(:database_version)

        expect(version).to eq('12.10')
      end

      it 'raises error when version query fails' do
        allow(mock_connection).to receive(:select_value).and_raise(StandardError.new('Query error'))

        expect {
          adapter.send(:database_version)
        }.to raise_error('Failed to get PostgreSQL version: Query error')
      end
    end

    context 'when ActiveRecord is not defined' do
      before do
        hide_const('ActiveRecord::Base') if defined?(ActiveRecord::Base)
      end

      it 'returns default version 12.0' do
        version = adapter.send(:database_version)

        expect(version).to eq('12.0')
      end
    end
  end

  describe '#version_supported?' do
    context 'when version is >= 12.0' do
      before do
        allow(adapter).to receive(:database_version).and_return('14.5')
      end

      it 'returns true' do
        expect(adapter.send(:version_supported?)).to be true
      end
    end

    context 'when version is exactly 12.0' do
      before do
        allow(adapter).to receive(:database_version).and_return('12.0')
      end

      it 'returns true' do
        expect(adapter.send(:version_supported?)).to be true
      end
    end

    context 'when version is < 12.0' do
      before do
        allow(adapter).to receive(:database_version).and_return('11.9')
      end

      it 'returns false' do
        expect(adapter.send(:version_supported?)).to be false
      end
    end

    context 'when version query fails' do
      before do
        allow(adapter).to receive(:database_version).and_raise(StandardError)
      end

      it 'returns false' do
        expect(adapter.send(:version_supported?)).to be false
      end
    end
  end

  describe '#encoding_compatible?' do
    context 'when ActiveRecord is defined' do
      let(:mock_connection) { instance_double('ActiveRecord::ConnectionAdapters::PostgreSQLAdapter') }
      let(:mock_base) { double('ActiveRecord::Base') }

      before do
        stub_const('ActiveRecord::Base', mock_base)
        allow(mock_base).to receive(:connection).and_return(mock_connection)
      end

      it 'returns true for UTF8 encoding' do
        allow(mock_connection).to receive(:select_value).with('SHOW server_encoding').and_return('UTF8')

        expect(adapter.send(:encoding_compatible?)).to be true
      end

      it 'returns true for UNICODE encoding' do
        allow(mock_connection).to receive(:select_value).with('SHOW server_encoding').and_return('UNICODE')

        expect(adapter.send(:encoding_compatible?)).to be true
      end

      it 'returns false for non-UTF8 encoding' do
        allow(mock_connection).to receive(:select_value).with('SHOW server_encoding').and_return('LATIN1')

        expect(adapter.send(:encoding_compatible?)).to be false
      end

      it 'returns false when encoding query fails' do
        allow(mock_connection).to receive(:select_value).and_raise(StandardError)

        expect(adapter.send(:encoding_compatible?)).to be false
      end
    end

    context 'when ActiveRecord is not defined' do
      before do
        hide_const('ActiveRecord::Base') if defined?(ActiveRecord::Base)
      end

      it 'returns true by default' do
        expect(adapter.send(:encoding_compatible?)).to be true
      end
    end
  end

  describe 'version constant' do
    it 'defines minimum version' do
      expect(described_class::MINIMUM_VERSION).to eq('12.0')
    end
  end
end
