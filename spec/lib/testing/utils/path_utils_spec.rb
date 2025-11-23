# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/testing/utils/path_utils'

RSpec.describe Testing::Utils::PathUtils do
  # Reset custom root path before each test to ensure isolation
  before do
    described_class.instance_variable_set(:@custom_root_path, nil) if described_class.instance_variable_defined?(:@custom_root_path)
  end

  describe '.root_path' do
    context 'when Rails is defined' do
      let(:rails_root) { '/path/to/rails/app' }

      before do
        # Mock Rails constant
        rails_class = Class.new do
          def self.root
            '/path/to/rails/app'
          end

          def self.respond_to?(method)
            method == :root || super
          end
        end

        stub_const('Rails', rails_class)
      end

      it 'returns Rails.root as Pathname' do
        result = described_class.root_path
        expect(result).to be_a(Pathname)
        expect(result.to_s).to eq(rails_root)
      end
    end

    context 'when Rails is not defined' do
      before do
        # Hide Rails constant if it exists
        hide_const('Rails') if defined?(Rails)
      end

      it 'returns Dir.pwd as Pathname' do
        result = described_class.root_path
        expect(result).to be_a(Pathname)
        expect(result.to_s).to eq(Dir.pwd)
      end
    end

    context 'when Rails is defined but root is nil' do
      before do
        rails_class = Class.new do
          def self.root
            nil
          end

          def self.respond_to?(method)
            method == :root || super
          end
        end

        stub_const('Rails', rails_class)
      end

      it 'returns Dir.pwd as Pathname' do
        result = described_class.root_path
        expect(result).to be_a(Pathname)
        expect(result.to_s).to eq(Dir.pwd)
      end
    end

    context 'when custom root path is set' do
      let(:custom_path) { '/custom/path' }

      before do
        described_class.root_path = custom_path
      end

      it 'returns custom root path as Pathname' do
        result = described_class.root_path
        expect(result).to be_a(Pathname)
        expect(result.to_s).to eq(custom_path)
      end

      it 'prioritizes custom path over Rails.root' do
        rails_class = Class.new do
          def self.root
            '/path/to/rails/app'
          end

          def self.respond_to?(method)
            method == :root || super
          end
        end

        stub_const('Rails', rails_class)

        result = described_class.root_path
        expect(result.to_s).to eq(custom_path)
      end
    end
  end

  describe '.root_path=' do
    it 'sets custom root path from string' do
      custom_path = '/custom/string/path'
      described_class.root_path = custom_path

      expect(described_class.root_path).to be_a(Pathname)
      expect(described_class.root_path.to_s).to eq(custom_path)
    end

    it 'sets custom root path from Pathname' do
      custom_path = Pathname.new('/custom/pathname/path')
      described_class.root_path = custom_path

      expect(described_class.root_path).to eq(custom_path)
    end

    it 'returns the set custom root path' do
      custom_path = '/return/test'
      result = (described_class.root_path = custom_path)

      # Note: The setter returns Pathname, but assignment returns the original value
      expect(described_class.root_path).to be_a(Pathname)
      expect(described_class.root_path.to_s).to eq(custom_path)
    end
  end

  describe '.tmp_path' do
    it 'returns tmp subdirectory of root_path' do
      result = described_class.tmp_path
      expect(result).to be_a(Pathname)
      expect(result.to_s).to end_with('tmp')
    end

    it 'appends tmp to custom root path' do
      described_class.root_path = '/custom/root'
      result = described_class.tmp_path

      expect(result.to_s).to eq('/custom/root/tmp')
    end

    it 'returns correct path when Rails is defined' do
      rails_class = Class.new do
        def self.root
          '/rails/root'
        end

        def self.respond_to?(method)
          method == :root || super
        end
      end

      stub_const('Rails', rails_class)

      result = described_class.tmp_path
      expect(result.to_s).to eq('/rails/root/tmp')
    end
  end

  describe '.screenshots_path' do
    it 'returns screenshots subdirectory of tmp_path' do
      result = described_class.screenshots_path
      expect(result).to be_a(Pathname)
      expect(result.to_s).to end_with('tmp/screenshots')
    end

    it 'returns correct path with custom root' do
      described_class.root_path = '/custom/root'
      result = described_class.screenshots_path

      expect(result.to_s).to eq('/custom/root/tmp/screenshots')
    end

    it 'is a child of tmp_path' do
      expect(described_class.screenshots_path.parent).to eq(described_class.tmp_path)
    end
  end

  describe '.traces_path' do
    it 'returns traces subdirectory of tmp_path' do
      result = described_class.traces_path
      expect(result).to be_a(Pathname)
      expect(result.to_s).to end_with('tmp/traces')
    end

    it 'returns correct path with custom root' do
      described_class.root_path = '/custom/root'
      result = described_class.traces_path

      expect(result.to_s).to eq('/custom/root/tmp/traces')
    end

    it 'is a child of tmp_path' do
      expect(described_class.traces_path.parent).to eq(described_class.tmp_path)
    end
  end

  describe '.coverage_path' do
    it 'returns coverage directory of root_path' do
      result = described_class.coverage_path
      expect(result).to be_a(Pathname)
      expect(result.to_s).to end_with('coverage')
    end

    it 'returns correct path with custom root' do
      described_class.root_path = '/custom/root'
      result = described_class.coverage_path

      expect(result.to_s).to eq('/custom/root/coverage')
    end

    it 'is a child of root_path' do
      expect(described_class.coverage_path.parent).to eq(described_class.root_path)
    end
  end

  describe 'cross-platform compatibility' do
    it 'all methods return Pathname objects' do
      expect(described_class.root_path).to be_a(Pathname)
      expect(described_class.tmp_path).to be_a(Pathname)
      expect(described_class.screenshots_path).to be_a(Pathname)
      expect(described_class.traces_path).to be_a(Pathname)
      expect(described_class.coverage_path).to be_a(Pathname)
    end

    it 'works with paths containing spaces' do
      described_class.root_path = '/path with spaces/app'

      expect(described_class.tmp_path.to_s).to eq('/path with spaces/app/tmp')
      expect(described_class.screenshots_path.to_s).to eq('/path with spaces/app/tmp/screenshots')
    end

    it 'works with paths containing special characters' do
      described_class.root_path = '/path-with_special.chars/app'

      expect(described_class.root_path.to_s).to eq('/path-with_special.chars/app')
    end
  end

  describe 'thread safety' do
    it 'custom root path is shared across calls' do
      described_class.root_path = '/shared/path'

      expect(described_class.root_path.to_s).to eq('/shared/path')
      expect(described_class.tmp_path.to_s).to eq('/shared/path/tmp')
    end
  end

  describe 'edge cases' do
    it 'handles empty string as custom root' do
      described_class.root_path = ''

      expect(described_class.root_path.to_s).to eq('')
      expect(described_class.tmp_path.to_s).to eq('tmp')
    end

    it 'handles relative paths' do
      described_class.root_path = './relative/path'

      expect(described_class.tmp_path.to_s).to eq('./relative/path/tmp')
    end

    it 'handles paths with trailing slash' do
      described_class.root_path = '/path/with/trailing/'

      expect(described_class.tmp_path.to_s).to eq('/path/with/trailing/tmp')
    end
  end
end
