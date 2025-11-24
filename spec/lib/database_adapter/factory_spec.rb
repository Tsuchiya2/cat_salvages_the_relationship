# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_adapter/factory'

RSpec.describe DatabaseAdapter::Factory do
  describe '.create' do
    context 'with MySQL adapter types' do
      it 'creates MySQL8Adapter for mysql2' do
        adapter = described_class.create('mysql2')
        expect(adapter).to be_a(DatabaseAdapter::MySQL8Adapter)
      end

      it 'creates MySQL8Adapter for mysql8' do
        adapter = described_class.create('mysql8')
        expect(adapter).to be_a(DatabaseAdapter::MySQL8Adapter)
      end
    end

    context 'with PostgreSQL adapter types' do
      it 'creates PostgreSQLAdapter for postgresql' do
        adapter = described_class.create('postgresql')
        expect(adapter).to be_a(DatabaseAdapter::PostgreSQLAdapter)
      end

      it 'creates PostgreSQLAdapter for pg' do
        adapter = described_class.create('pg')
        expect(adapter).to be_a(DatabaseAdapter::PostgreSQLAdapter)
      end
    end

    context 'with unsupported adapter type' do
      it 'raises ArgumentError' do
        expect { described_class.create('oracle') }.to raise_error(ArgumentError, /Unsupported adapter type/)
      end
    end

    context 'with configuration' do
      it 'passes configuration to adapter' do
        config = { host: 'localhost', port: 3306 }
        adapter = described_class.create('mysql2', config)
        expect(adapter.config).to eq(config)
      end
    end
  end

  describe '.current_adapter' do
    context 'when ActiveRecord is defined' do
      before do
        allow(ActiveRecord::Base).to receive_message_chain(:connection, :adapter_name).and_return('Mysql2')
      end

      it 'creates adapter for current connection' do
        adapter = described_class.current_adapter
        expect(adapter).to be_a(DatabaseAdapter::MySQL8Adapter)
      end
    end

    context 'when ActiveRecord is not defined' do
      it 'returns nil' do
        stub_const('ActiveRecord', nil)
        expect(described_class.current_adapter).to be_nil
      end
    end
  end
end
