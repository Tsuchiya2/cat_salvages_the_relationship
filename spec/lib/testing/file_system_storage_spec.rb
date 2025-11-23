# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'json'
require 'tempfile'
require_relative '../../../lib/testing/file_system_storage'
require_relative '../../../lib/testing/utils/path_utils'
require_relative '../../../lib/testing/utils/string_utils'

RSpec.describe Testing::FileSystemStorage do
  let(:temp_dir) { Dir.mktmpdir('test-artifacts') }
  let(:storage) { described_class.new(base_path: temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  describe '#initialize' do
    it 'creates storage with default base path' do
      default_storage = described_class.new
      expect(default_storage.base_path).to be_a(Pathname)
    end

    it 'creates storage with custom base path' do
      expect(storage.base_path.to_s).to eq(temp_dir)
    end

    it 'creates screenshots directory on initialization' do
      expect(File.exist?(File.join(temp_dir, 'screenshots'))).to be true
    end

    it 'creates traces directory on initialization' do
      expect(File.exist?(File.join(temp_dir, 'traces'))).to be true
    end

    it 'accepts base path as string' do
      storage = described_class.new(base_path: temp_dir)
      expect(storage.base_path).to be_a(Pathname)
      expect(storage.base_path.to_s).to eq(temp_dir)
    end

    it 'accepts base path as Pathname' do
      storage = described_class.new(base_path: Pathname.new(temp_dir))
      expect(storage.base_path).to be_a(Pathname)
      expect(storage.base_path.to_s).to eq(temp_dir)
    end
  end

  describe '#save_screenshot' do
    let(:screenshot_file) { Tempfile.new(['test-screenshot', '.png']) }
    let(:screenshot_path) { screenshot_file.path }

    before do
      screenshot_file.write('fake screenshot data')
      screenshot_file.close
    end

    after do
      screenshot_file.unlink
    end

    it 'saves screenshot to screenshots directory' do
      result = storage.save_screenshot('test-screenshot', screenshot_path)

      expect(result).to be_a(Pathname)
      expect(result.to_s).to include('screenshots')
      expect(File.exist?(result)).to be true
    end

    it 'sanitizes screenshot filename' do
      result = storage.save_screenshot('test/screenshot:with*special?chars', screenshot_path)

      expect(result.basename.to_s).to match(/test_screenshot_with_special_chars/)
    end

    it 'preserves file extension' do
      result = storage.save_screenshot('test-screenshot', screenshot_path)

      expect(result.extname).to eq('.png')
    end

    it 'copies file content correctly' do
      result = storage.save_screenshot('test-screenshot', screenshot_path)

      expect(File.read(result)).to eq('fake screenshot data')
    end

    it 'saves metadata as JSON file' do
      metadata = { test_name: 'My Test', timestamp: '2025-11-23' }
      result = storage.save_screenshot('test-screenshot', screenshot_path, metadata)

      metadata_path = "#{result}.metadata.json"
      expect(File.exist?(metadata_path)).to be true

      saved_metadata = JSON.parse(File.read(metadata_path), symbolize_names: true)
      expect(saved_metadata[:test_name]).to eq('My Test')
      expect(saved_metadata[:timestamp]).to eq('2025-11-23')
    end

    it 'includes default metadata fields' do
      result = storage.save_screenshot('test-screenshot', screenshot_path, { custom: 'value' })

      metadata_path = "#{result}.metadata.json"
      saved_metadata = JSON.parse(File.read(metadata_path), symbolize_names: true)

      expect(saved_metadata).to have_key(:type)
      expect(saved_metadata).to have_key(:saved_at)
      expect(saved_metadata[:type]).to eq('screenshot')
      expect(saved_metadata[:custom]).to eq('value')
    end

    it 'raises error if source file does not exist' do
      expect do
        storage.save_screenshot('test', '/non/existent/file.png')
      end.to raise_error(Errno::ENOENT)
    end

    it 'returns Pathname object' do
      result = storage.save_screenshot('test-screenshot', screenshot_path)

      expect(result).to be_a(Pathname)
    end

    it 'handles empty metadata' do
      result = storage.save_screenshot('test-screenshot', screenshot_path, {})

      metadata_path = "#{result}.metadata.json"
      expect(File.exist?(metadata_path)).to be true
    end

    it 'handles nil metadata' do
      result = storage.save_screenshot('test-screenshot', screenshot_path, nil)

      metadata_path = "#{result}.metadata.json"
      expect(File.exist?(metadata_path)).to be true
    end
  end

  describe '#save_trace' do
    let(:trace_file) { Tempfile.new(['test-trace', '.zip']) }
    let(:trace_path) { trace_file.path }

    before do
      trace_file.write('fake trace data')
      trace_file.close
    end

    after do
      trace_file.unlink
    end

    it 'saves trace to traces directory' do
      result = storage.save_trace('test-trace', trace_path)

      expect(result).to be_a(Pathname)
      expect(result.to_s).to include('traces')
      expect(File.exist?(result)).to be true
    end

    it 'sanitizes trace filename' do
      result = storage.save_trace('test/trace:with*special?chars', trace_path)

      expect(result.basename.to_s).to match(/test_trace_with_special_chars/)
    end

    it 'preserves file extension' do
      result = storage.save_trace('test-trace', trace_path)

      expect(result.extname).to eq('.zip')
    end

    it 'copies file content correctly' do
      result = storage.save_trace('test-trace', trace_path)

      expect(File.read(result)).to eq('fake trace data')
    end

    it 'saves metadata as JSON file' do
      metadata = { test_name: 'My Test', duration: 1234 }
      result = storage.save_trace('test-trace', trace_path, metadata)

      metadata_path = "#{result}.metadata.json"
      expect(File.exist?(metadata_path)).to be true

      saved_metadata = JSON.parse(File.read(metadata_path), symbolize_names: true)
      expect(saved_metadata[:test_name]).to eq('My Test')
      expect(saved_metadata[:duration]).to eq(1234)
    end

    it 'includes default metadata fields' do
      result = storage.save_trace('test-trace', trace_path, { custom: 'value' })

      metadata_path = "#{result}.metadata.json"
      saved_metadata = JSON.parse(File.read(metadata_path), symbolize_names: true)

      expect(saved_metadata).to have_key(:type)
      expect(saved_metadata).to have_key(:saved_at)
      expect(saved_metadata[:type]).to eq('trace')
      expect(saved_metadata[:custom]).to eq('value')
    end

    it 'returns Pathname object' do
      result = storage.save_trace('test-trace', trace_path)

      expect(result).to be_a(Pathname)
    end
  end

  describe '#list_artifacts' do
    let(:screenshot_file) { Tempfile.new(['screenshot', '.png']) }
    let(:trace_file) { Tempfile.new(['trace', '.zip']) }

    before do
      screenshot_file.write('screenshot')
      screenshot_file.close
      trace_file.write('trace')
      trace_file.close
    end

    after do
      screenshot_file.unlink
      trace_file.unlink
    end

    it 'returns empty array when no artifacts exist' do
      result = storage.list_artifacts

      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    it 'returns list of screenshots' do
      storage.save_screenshot('test-screenshot', screenshot_file.path)

      result = storage.list_artifacts

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq('screenshot')
      expect(result.first[:name]).to include('test-screenshot')
    end

    it 'returns list of traces' do
      storage.save_trace('test-trace', trace_file.path)

      result = storage.list_artifacts

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq('trace')
      expect(result.first[:name]).to include('test-trace')
    end

    it 'returns combined list of screenshots and traces' do
      storage.save_screenshot('test-screenshot', screenshot_file.path)
      storage.save_trace('test-trace', trace_file.path)

      result = storage.list_artifacts

      expect(result.size).to eq(2)
      types = result.map { |a| a[:type] }
      expect(types).to contain_exactly('screenshot', 'trace')
    end

    it 'includes file paths in artifact list' do
      storage.save_screenshot('test-screenshot', screenshot_file.path)

      result = storage.list_artifacts

      expect(result.first[:path]).to be_a(Pathname)
      expect(File.exist?(result.first[:path])).to be true
    end

    it 'sorts artifacts by creation time (most recent first)' do
      storage.save_screenshot('first', screenshot_file.path)
      sleep 0.1
      storage.save_screenshot('second', screenshot_file.path)

      result = storage.list_artifacts

      expect(result.first[:name]).to include('second')
      expect(result.last[:name]).to include('first')
    end

    it 'excludes metadata files from listing' do
      storage.save_screenshot('test-screenshot', screenshot_file.path)

      screenshots_dir = File.join(temp_dir, 'screenshots')
      all_files = Dir.glob(File.join(screenshots_dir, '*'))

      expect(all_files.size).to be >= 2 # artifact + metadata

      result = storage.list_artifacts
      expect(result.size).to eq(1) # only artifact, not metadata
    end
  end

  describe '#get_artifact' do
    let(:screenshot_file) { Tempfile.new(['screenshot', '.png']) }

    before do
      screenshot_file.write('screenshot data')
      screenshot_file.close
    end

    after do
      screenshot_file.unlink
    end

    it 'returns artifact content as binary string' do
      saved_path = storage.save_screenshot('test-screenshot', screenshot_file.path)

      result = storage.get_artifact(saved_path.basename.to_s)

      expect(result).to eq('screenshot data')
    end

    it 'raises error if artifact does not exist' do
      expect do
        storage.get_artifact('non-existent-artifact.png')
      end.to raise_error(Errno::ENOENT)
    end

    it 'searches in traces directory' do
      trace_file = Tempfile.new(['trace', '.zip'])
      trace_file.write('trace data')
      trace_file.close

      saved_path = storage.save_trace('test-trace', trace_file.path)

      result = storage.get_artifact(saved_path.basename.to_s)

      expect(result).to eq('trace data')

      trace_file.unlink
    end
  end

  describe '#delete_artifact' do
    let(:screenshot_file) { Tempfile.new(['screenshot', '.png']) }

    before do
      screenshot_file.write('screenshot data')
      screenshot_file.close
    end

    after do
      screenshot_file.unlink
    end

    it 'deletes artifact file' do
      saved_path = storage.save_screenshot('test-screenshot', screenshot_file.path)

      expect(File.exist?(saved_path)).to be true

      storage.delete_artifact(saved_path.basename.to_s)

      expect(File.exist?(saved_path)).to be false
    end

    it 'deletes metadata file' do
      saved_path = storage.save_screenshot('test-screenshot', screenshot_file.path, { test: 'data' })
      metadata_path = "#{saved_path}.metadata.json"

      expect(File.exist?(metadata_path)).to be true

      storage.delete_artifact(saved_path.basename.to_s)

      expect(File.exist?(metadata_path)).to be false
    end

    it 'returns true when deletion succeeds' do
      saved_path = storage.save_screenshot('test-screenshot', screenshot_file.path)

      result = storage.delete_artifact(saved_path.basename.to_s)

      expect(result).to be true
    end

    it 'raises error if artifact does not exist' do
      expect do
        storage.delete_artifact('non-existent-artifact.png')
      end.to raise_error(Errno::ENOENT)
    end

    it 'deletes from screenshots directory' do
      saved_path = storage.save_screenshot('test-screenshot', screenshot_file.path)

      storage.delete_artifact(saved_path.basename.to_s)

      expect(File.exist?(saved_path)).to be false
    end

    it 'deletes from traces directory' do
      trace_file = Tempfile.new(['trace', '.zip'])
      trace_file.write('trace data')
      trace_file.close

      saved_path = storage.save_trace('test-trace', trace_file.path)

      storage.delete_artifact(saved_path.basename.to_s)

      expect(File.exist?(saved_path)).to be false

      trace_file.unlink
    end
  end

  describe 'integration with PathUtils' do
    it 'uses PathUtils.tmp_path as default base path' do
      default_storage = described_class.new

      expect(default_storage.base_path.to_s).to include('tmp')
    end
  end

  describe 'integration with StringUtils' do
    let(:screenshot_file) { Tempfile.new(['screenshot', '.png']) }

    before do
      screenshot_file.write('data')
      screenshot_file.close
    end

    after do
      screenshot_file.unlink
    end

    it 'sanitizes filenames using StringUtils' do
      result = storage.save_screenshot('test/screenshot:with*special', screenshot_file.path)

      expect(result.basename.to_s).not_to include('/')
      expect(result.basename.to_s).not_to include(':')
      expect(result.basename.to_s).not_to include('*')
    end
  end

  describe 'error handling' do
    it 'handles permission errors gracefully' do
      allow(FileUtils).to receive(:cp).and_raise(Errno::EACCES.new('Permission denied'))

      screenshot_file = Tempfile.new(['screenshot', '.png'])
      screenshot_file.write('data')
      screenshot_file.close

      expect do
        storage.save_screenshot('test', screenshot_file.path)
      end.to raise_error(Errno::EACCES)

      screenshot_file.unlink
    end

    it 'handles disk full errors gracefully' do
      allow(FileUtils).to receive(:cp).and_raise(Errno::ENOSPC.new('No space left on device'))

      screenshot_file = Tempfile.new(['screenshot', '.png'])
      screenshot_file.write('data')
      screenshot_file.close

      expect do
        storage.save_screenshot('test', screenshot_file.path)
      end.to raise_error(Errno::ENOSPC)

      screenshot_file.unlink
    end
  end

  describe 'concurrency safety' do
    it 'creates directories with mkdir_p (idempotent)' do
      # Create multiple storage instances simultaneously
      described_class.new(base_path: temp_dir)
      described_class.new(base_path: temp_dir)

      expect(File.exist?(File.join(temp_dir, 'screenshots'))).to be true
      expect(File.exist?(File.join(temp_dir, 'traces'))).to be true
    end
  end
end
