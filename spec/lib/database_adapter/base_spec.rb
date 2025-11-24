# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_adapter/base'

RSpec.describe DatabaseAdapter::Base do
  # Create a test implementation of the base adapter
  let(:test_adapter_class) do
    Class.new(described_class) do
      def adapter_name
        'test_adapter'
      end

      def migrate_from(_source_adapter, _options = {})
        { status: 'completed' }
      end

      def verify_compatibility
        { version_check: true }
      end

      def connection_params
        { adapter: 'test', host: 'localhost' }
      end

      protected

      def database_version
        '1.0.0'
      end

      def version_supported?
        true
      end
    end
  end

  let(:adapter) { test_adapter_class.new }
  let(:incomplete_adapter_class) { Class.new(described_class) }
  let(:incomplete_adapter) { incomplete_adapter_class.new }

  describe '#initialize' do
    it 'initializes with empty config by default' do
      adapter = test_adapter_class.new
      expect(adapter.config).to eq({})
    end

    it 'initializes with provided config' do
      config = { host: 'localhost', port: 3306 }
      adapter = test_adapter_class.new(config)
      expect(adapter.config).to eq(config)
    end
  end

  describe '#adapter_name' do
    it 'raises NotImplementedError for base class' do
      expect {
        incomplete_adapter.adapter_name
      }.to raise_error(NotImplementedError, /must implement adapter_name/)
    end

    it 'returns adapter name when implemented' do
      expect(adapter.adapter_name).to eq('test_adapter')
    end
  end

  describe '#migrate_from' do
    it 'raises NotImplementedError for base class' do
      source_adapter = instance_double('DatabaseAdapter::Base')

      expect {
        incomplete_adapter.migrate_from(source_adapter)
      }.to raise_error(NotImplementedError, /must implement migrate_from/)
    end

    it 'executes migration when implemented' do
      source_adapter = instance_double('DatabaseAdapter::Base')
      result = adapter.migrate_from(source_adapter)

      expect(result[:status]).to eq('completed')
    end

    it 'accepts options parameter' do
      source_adapter = instance_double('DatabaseAdapter::Base')
      options = { parallel: true, workers: 4 }

      expect {
        adapter.migrate_from(source_adapter, options)
      }.not_to raise_error
    end
  end

  describe '#verify_compatibility' do
    it 'raises NotImplementedError for base class' do
      expect {
        incomplete_adapter.verify_compatibility
      }.to raise_error(NotImplementedError, /must implement verify_compatibility/)
    end

    it 'returns compatibility check results when implemented' do
      result = adapter.verify_compatibility

      expect(result).to be_a(Hash)
      expect(result[:version_check]).to be true
    end
  end

  describe '#connection_params' do
    it 'raises NotImplementedError for base class' do
      expect {
        incomplete_adapter.connection_params
      }.to raise_error(NotImplementedError, /must implement connection_params/)
    end

    it 'returns connection parameters when implemented' do
      params = adapter.connection_params

      expect(params).to be_a(Hash)
      expect(params[:adapter]).to eq('test')
      expect(params[:host]).to eq('localhost')
    end
  end

  describe '#version_info' do
    it 'returns version information hash' do
      info = adapter.version_info

      expect(info).to be_a(Hash)
      expect(info).to have_key(:adapter)
      expect(info).to have_key(:version)
      expect(info).to have_key(:supported)
    end

    it 'includes adapter name' do
      info = adapter.version_info

      expect(info[:adapter]).to eq('test_adapter')
    end

    it 'includes database version' do
      info = adapter.version_info

      expect(info[:version]).to eq('1.0.0')
    end

    it 'includes version supported status' do
      info = adapter.version_info

      expect(info[:supported]).to be true
    end
  end

  describe '#database_version' do
    it 'raises NotImplementedError for base class' do
      expect {
        incomplete_adapter.send(:database_version)
      }.to raise_error(NotImplementedError, /must implement database_version/)
    end

    it 'returns version string when implemented' do
      version = adapter.send(:database_version)

      expect(version).to eq('1.0.0')
    end
  end

  describe '#version_supported?' do
    it 'raises NotImplementedError for base class' do
      expect {
        incomplete_adapter.send(:version_supported?)
      }.to raise_error(NotImplementedError, /must implement version_supported?/)
    end

    it 'returns boolean when implemented' do
      supported = adapter.send(:version_supported?)

      expect(supported).to be true
    end
  end

  describe 'interface compliance' do
    it 'requires adapter_name to be implemented' do
      expect(incomplete_adapter_class.instance_methods(false)).not_to include(:adapter_name)
    end

    it 'requires migrate_from to be implemented' do
      expect(incomplete_adapter_class.instance_methods(false)).not_to include(:migrate_from)
    end

    it 'requires verify_compatibility to be implemented' do
      expect(incomplete_adapter_class.instance_methods(false)).not_to include(:verify_compatibility)
    end

    it 'requires connection_params to be implemented' do
      expect(incomplete_adapter_class.instance_methods(false)).not_to include(:connection_params)
    end

    it 'requires database_version to be implemented' do
      expect(incomplete_adapter_class.private_instance_methods(false)).not_to include(:database_version)
    end

    it 'requires version_supported? to be implemented' do
      expect(incomplete_adapter_class.private_instance_methods(false)).not_to include(:version_supported?)
    end
  end

  describe 'config accessor' do
    it 'provides read access to config' do
      config = { host: 'testhost', port: 5432 }
      adapter = test_adapter_class.new(config)

      expect(adapter.config).to eq(config)
    end

    it 'does not allow direct modification of config' do
      adapter = test_adapter_class.new

      expect { adapter.config = { new: 'config' } }.to raise_error(NoMethodError)
    end
  end
end
