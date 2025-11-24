# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_migration/strategy_factory'

RSpec.describe DatabaseMigration::StrategyFactory do
  describe '.create' do
    context 'with PostgreSQL to MySQL migration' do
      it 'creates PostgreSQLToMySQL8Strategy' do
        strategy = described_class.create(source: 'postgresql', target: 'mysql2')
        expect(strategy).to be_a(DatabaseMigration::Strategies::PostgreSQLToMySQL8Strategy)
      end

      it 'accepts pg as source alias' do
        strategy = described_class.create(source: 'pg', target: 'mysql8')
        expect(strategy).to be_a(DatabaseMigration::Strategies::PostgreSQLToMySQL8Strategy)
      end
    end

    context 'with unsupported migration path' do
      it 'raises ArgumentError' do
        expect do
          described_class.create(source: 'oracle', target: 'mysql2')
        end.to raise_error(ArgumentError, /No migration strategy found/)
      end
    end

    context 'with configuration' do
      it 'passes configuration to strategy' do
        config = { tool: :pgloader, parallel_workers: 4 }
        strategy = described_class.create(source: 'postgresql', target: 'mysql2', config: config)

        expect(strategy.config[:tool]).to eq(:pgloader)
        expect(strategy.config[:parallel_workers]).to eq(4)
      end
    end
  end

  describe '.available_strategies' do
    it 'returns list of available migration paths' do
      strategies = described_class.available_strategies

      expect(strategies).to be_an(Array)
      expect(strategies).not_to be_empty
      expect(strategies).to include(match(/postgresql.*mysql/i))
    end
  end
end
