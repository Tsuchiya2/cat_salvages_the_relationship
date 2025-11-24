# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/migration_utils/data_verifier'

RSpec.describe MigrationUtils::DataVerifier do
  let(:source_connection) { double('source_connection') }
  let(:target_connection) { double('target_connection') }
  let(:verifier) { described_class.new(source_connection, target_connection) }

  describe '#initialize' do
    it 'stores source and target connections' do
      expect(verifier.source_connection).to eq(source_connection)
      expect(verifier.target_connection).to eq(target_connection)
    end
  end

  describe '#verify_row_counts' do
    let(:tables) { %w[users posts] }

    before do
      allow(source_connection).to receive(:select_value).with(/users/).and_return(100)
      allow(source_connection).to receive(:select_value).with(/posts/).and_return(50)
      allow(target_connection).to receive(:select_value).with(/users/).and_return(100)
      allow(target_connection).to receive(:select_value).with(/posts/).and_return(50)
      allow(source_connection).to receive(:quote_table_name) { |name| "`#{name}`" }
      allow(target_connection).to receive(:quote_table_name) { |name| "`#{name}`" }
    end

    it 'compares row counts for all tables' do
      result = verifier.verify_row_counts(tables)

      expect(result[:table_results].size).to eq(2)
      expect(result[:all_matched]).to be true
      expect(result[:total_source_rows]).to eq(150)
      expect(result[:total_target_rows]).to eq(150)
    end

    context 'when counts do not match' do
      before do
        allow(target_connection).to receive(:select_value).with(/users/).and_return(95)
      end

      it 'identifies mismatches' do
        result = verifier.verify_row_counts(tables)

        expect(result[:all_matched]).to be false
        expect(result[:mismatches].size).to eq(1)
        expect(result[:mismatches].first[:table]).to eq('users')
        expect(result[:mismatches].first[:difference]).to eq(5)
      end
    end
  end

  describe '#verify_schema_compatibility' do
    let(:table) { 'users' }
    let(:source_columns) { double('source_columns') }
    let(:target_columns) { double('target_columns') }

    before do
      allow(source_connection).to receive(:columns).with(table).and_return(source_columns)
      allow(target_connection).to receive(:columns).with(table).and_return(target_columns)
      allow(source_columns).to receive(:map).and_return(%w[id name email])
      allow(target_columns).to receive(:map).and_return(%w[id name email])
    end

    it 'compares column structures' do
      result = verifier.verify_schema_compatibility(table)

      expect(result[:table]).to eq(table)
      expect(result[:columns_match]).to be true
      expect(result[:missing_in_target]).to be_empty
      expect(result[:extra_in_target]).to be_empty
    end

    context 'when columns differ' do
      before do
        allow(target_columns).to receive(:map).and_return(%w[id name])
      end

      it 'identifies missing columns' do
        result = verifier.verify_schema_compatibility(table)

        expect(result[:columns_match]).to be false
        expect(result[:missing_in_target]).to include('email')
      end
    end
  end

  describe '#verify_all' do
    let(:tables) { %w[users] }

    before do
      allow(source_connection).to receive(:select_value).and_return(100)
      allow(target_connection).to receive(:select_value).and_return(100)
      allow(source_connection).to receive(:quote_table_name) { |name| "`#{name}`" }
      allow(target_connection).to receive(:quote_table_name) { |name| "`#{name}`" }
      allow(source_connection).to receive(:columns).and_return([])
      allow(target_connection).to receive(:columns).and_return([])
      allow(source_connection).to receive(:primary_key).and_return('id')
      allow(target_connection).to receive(:primary_key).and_return('id')
      allow(source_connection).to receive(:quote_column_name) { |name| "`#{name}`" }
      allow(target_connection).to receive(:quote_column_name) { |name| "`#{name}`" }
      allow(source_connection).to receive(:select_all).and_return([])
      allow(target_connection).to receive(:select_all).and_return([])
    end

    it 'performs comprehensive verification' do
      result = verifier.verify_all(tables)

      expect(result).to include(
        row_counts: instance_of(Hash),
        schemas: instance_of(Array),
        checksums: instance_of(Array),
        timestamp: instance_of(String)
      )
      expect([true, false]).to include(result[:all_passed])
    end

    context 'with skip_checksums option' do
      it 'skips checksum verification' do
        result = verifier.verify_all(tables, skip_checksums: true)

        expect(result[:checksums]).to be_empty
      end
    end
  end
end
