# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/testing/artifact_storage'

RSpec.describe Testing::ArtifactStorage do
  let(:storage) { described_class.new }

  describe '#save_screenshot' do
    it 'raises NotImplementedError' do
      expect do
        storage.save_screenshot('test-screenshot', '/path/to/file.png', { test: 'metadata' })
      end.to raise_error(NotImplementedError, /must implement save_screenshot/)
    end

    it 'includes method signature in error message' do
      expect do
        storage.save_screenshot('test', '/path/to/file.png')
      end.to raise_error(NotImplementedError, /save_screenshot/)
    end
  end

  describe '#save_trace' do
    it 'raises NotImplementedError' do
      expect do
        storage.save_trace('test-trace', '/path/to/trace.zip', { test: 'metadata' })
      end.to raise_error(NotImplementedError, /must implement save_trace/)
    end

    it 'includes method signature in error message' do
      expect do
        storage.save_trace('test', '/path/to/trace.zip')
      end.to raise_error(NotImplementedError, /save_trace/)
    end
  end

  describe '#list_artifacts' do
    it 'raises NotImplementedError' do
      expect do
        storage.list_artifacts
      end.to raise_error(NotImplementedError, /must implement list_artifacts/)
    end

    it 'includes method signature in error message' do
      expect do
        storage.list_artifacts
      end.to raise_error(NotImplementedError, /list_artifacts/)
    end
  end

  describe '#get_artifact' do
    it 'raises NotImplementedError' do
      expect do
        storage.get_artifact('test-artifact')
      end.to raise_error(NotImplementedError, /must implement get_artifact/)
    end

    it 'includes method signature in error message' do
      expect do
        storage.get_artifact('test')
      end.to raise_error(NotImplementedError, /get_artifact/)
    end
  end

  describe '#delete_artifact' do
    it 'raises NotImplementedError' do
      expect do
        storage.delete_artifact('test-artifact')
      end.to raise_error(NotImplementedError, /must implement delete_artifact/)
    end

    it 'includes method signature in error message' do
      expect do
        storage.delete_artifact('test')
      end.to raise_error(NotImplementedError, /delete_artifact/)
    end
  end

  describe 'interface contract' do
    it 'defines all required methods' do
      expect(storage).to respond_to(:save_screenshot)
      expect(storage).to respond_to(:save_trace)
      expect(storage).to respond_to(:list_artifacts)
      expect(storage).to respond_to(:get_artifact)
      expect(storage).to respond_to(:delete_artifact)
    end

    it 'save_screenshot accepts name, file_path, and optional metadata' do
      expect(storage.method(:save_screenshot).arity).to eq(-2).or eq(-3)
    end

    it 'save_trace accepts name, file_path, and optional metadata' do
      expect(storage.method(:save_trace).arity).to eq(-2).or eq(-3)
    end

    it 'list_artifacts accepts no required arguments' do
      expect(storage.method(:list_artifacts).arity).to eq(0)
    end

    it 'get_artifact accepts one argument (name)' do
      expect(storage.method(:get_artifact).arity).to eq(1)
    end

    it 'delete_artifact accepts one argument (name)' do
      expect(storage.method(:delete_artifact).arity).to eq(1)
    end
  end

  describe 'documentation' do
    it 'provides clear error messages for subclass implementation' do
      error_message = nil

      begin
        storage.save_screenshot('test', '/path')
      rescue NotImplementedError => e
        error_message = e.message
      end

      expect(error_message).to match(/subclass/i).or match(/implement/i)
    end
  end

  describe 'inheritance pattern' do
    let(:custom_storage_class) do
      Class.new(described_class) do
        def save_screenshot(name, file_path, metadata = {})
          { name: name, file_path: file_path, metadata: metadata }
        end

        def save_trace(name, file_path, metadata = {})
          { name: name, file_path: file_path, metadata: metadata }
        end

        def list_artifacts
          []
        end

        def get_artifact(name)
          { name: name, content: 'test' }
        end

        def delete_artifact(_name)
          true
        end
      end
    end

    let(:custom_storage) { custom_storage_class.new }

    it 'allows subclasses to override save_screenshot' do
      result = custom_storage.save_screenshot('test', '/path', { key: 'value' })
      expect(result).to eq({ name: 'test', file_path: '/path', metadata: { key: 'value' } })
    end

    it 'allows subclasses to override save_trace' do
      result = custom_storage.save_trace('test', '/path', { key: 'value' })
      expect(result).to eq({ name: 'test', file_path: '/path', metadata: { key: 'value' } })
    end

    it 'allows subclasses to override list_artifacts' do
      result = custom_storage.list_artifacts
      expect(result).to eq([])
    end

    it 'allows subclasses to override get_artifact' do
      result = custom_storage.get_artifact('test')
      expect(result).to eq({ name: 'test', content: 'test' })
    end

    it 'allows subclasses to override delete_artifact' do
      result = custom_storage.delete_artifact('test')
      expect(result).to be true
    end
  end
end
