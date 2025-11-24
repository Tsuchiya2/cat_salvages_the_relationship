# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_adapter/mysql8_adapter'

RSpec.describe DatabaseAdapter::MySQL8Adapter do
  let(:adapter) { described_class.new }

  describe '#adapter_name' do
    it 'returns mysql2' do
      expect(adapter.adapter_name).to eq('mysql2')
    end
  end

  describe '#connection_params' do
    it 'returns MySQL connection parameters' do
      params = adapter.connection_params

      expect(params[:adapter]).to eq('mysql2')
      expect(params[:encoding]).to eq('utf8mb4')
      expect(params[:collation]).to eq('utf8mb4_unicode_ci')
      expect(params[:pool]).to be_a(Integer)
      expect(params[:timeout]).to eq(5000)
      expect(params[:reconnect]).to be true
    end

    it 'merges custom configuration' do
      custom_adapter = described_class.new(database: 'custom_db', host: 'custom_host')
      params = custom_adapter.connection_params

      expect(params[:database]).to eq('custom_db')
      expect(params[:host]).to eq('custom_host')
    end
  end

  describe '#version_info' do
    before do
      allow(adapter).to receive(:database_version).and_return('8.0.34')
      allow(adapter).to receive(:version_supported?).and_return(true)
    end

    it 'returns version information' do
      info = adapter.version_info

      expect(info[:adapter]).to eq('mysql2')
      expect(info[:version]).to eq('8.0.34')
      expect(info[:supported]).to be true
    end
  end

  describe '#verify_compatibility' do
    context 'when all checks pass' do
      before do
        allow(adapter).to receive(:version_supported?).and_return(true)
        allow(adapter).to receive(:encoding_compatible?).and_return(true)
        allow(adapter).to receive(:required_features_available?).and_return(true)
      end

      it 'returns successful checks' do
        result = adapter.verify_compatibility

        expect(result[:version_check]).to be true
        expect(result[:encoding_check]).to be true
        expect(result[:features_check]).to be true
      end
    end

    context 'when a check fails' do
      before do
        allow(adapter).to receive(:version_supported?).and_return(false)
        allow(adapter).to receive(:encoding_compatible?).and_return(true)
        allow(adapter).to receive(:required_features_available?).and_return(true)
      end

      it 'raises CompatibilityError' do
        expect { adapter.verify_compatibility }.to raise_error(DatabaseAdapter::CompatibilityError)
      end
    end
  end

  describe 'version constants' do
    it 'defines minimum version' do
      expect(described_class::MINIMUM_VERSION).to eq('8.0.0')
    end

    it 'defines recommended version' do
      expect(described_class::RECOMMENDED_VERSION).to eq('8.0.34')
    end
  end
end
