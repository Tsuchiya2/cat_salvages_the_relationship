# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/testing/utils/env_utils'

RSpec.describe Testing::Utils::EnvUtils do
  # Helper method to temporarily set environment variables
  def with_env(vars)
    original_values = {}
    vars.each do |key, value|
      key_str = key.to_s
      original_values[key_str] = ENV[key_str]
      if value.nil?
        ENV.delete(key_str)
      else
        ENV[key_str] = value
      end
    end

    yield
  ensure
    original_values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  describe '.environment' do
    context 'when Rails is defined' do
      before do
        # Mock Rails.env without ActiveSupport dependency
        mock_env = double('rails_env', to_s: 'test')

        rails_class = Class.new do
          define_singleton_method(:env) { mock_env }

          def self.respond_to?(method)
            method == :env || super
          end
        end

        stub_const('Rails', rails_class)
      end

      it 'returns Rails.env as string' do
        result = described_class.environment
        expect(result).to eq('test')
      end
    end

    context 'when Rails is not defined' do
      before do
        hide_const('Rails') if defined?(Rails)
      end

      it 'returns RACK_ENV when set' do
        with_env(RACK_ENV: 'production', APP_ENV: 'development') do
          expect(described_class.environment).to eq('production')
        end
      end

      it 'returns APP_ENV when RACK_ENV is not set' do
        with_env(RACK_ENV: nil, APP_ENV: 'staging') do
          expect(described_class.environment).to eq('staging')
        end
      end

      it 'returns development when no environment variables set' do
        with_env(RACK_ENV: nil, APP_ENV: nil) do
          expect(described_class.environment).to eq('development')
        end
      end

      it 'prioritizes RACK_ENV over APP_ENV' do
        with_env(RACK_ENV: 'rack_value', APP_ENV: 'app_value') do
          expect(described_class.environment).to eq('rack_value')
        end
      end
    end

    context 'when Rails.env is nil' do
      before do
        rails_class = Class.new do
          def self.env
            nil
          end

          def self.respond_to?(method)
            method == :env || super
          end
        end

        stub_const('Rails', rails_class)
      end

      it 'falls back to RACK_ENV/APP_ENV' do
        with_env(RACK_ENV: 'fallback') do
          expect(described_class.environment).to eq('fallback')
        end
      end
    end
  end

  describe '.test_environment?' do
    it 'returns true when environment is test' do
      allow(described_class).to receive(:environment).and_return('test')
      expect(described_class.test_environment?).to be true
    end

    it 'returns false when environment is not test' do
      allow(described_class).to receive(:environment).and_return('development')
      expect(described_class.test_environment?).to be false
    end

    it 'returns false when environment is production' do
      allow(described_class).to receive(:environment).and_return('production')
      expect(described_class.test_environment?).to be false
    end
  end

  describe '.ci_environment?' do
    it 'returns true when GITHUB_ACTIONS is true' do
      with_env(GITHUB_ACTIONS: 'true', CI: nil) do
        expect(described_class.ci_environment?).to be true
      end
    end

    it 'returns true when CI is true' do
      with_env(GITHUB_ACTIONS: nil, CI: 'true') do
        expect(described_class.ci_environment?).to be true
      end
    end

    it 'returns true when both GITHUB_ACTIONS and CI are true' do
      with_env(GITHUB_ACTIONS: 'true', CI: 'true') do
        expect(described_class.ci_environment?).to be true
      end
    end

    it 'returns false when GITHUB_ACTIONS is false' do
      with_env(GITHUB_ACTIONS: 'false', CI: nil) do
        expect(described_class.ci_environment?).to be false
      end
    end

    it 'returns false when CI is false' do
      with_env(GITHUB_ACTIONS: nil, CI: 'false') do
        expect(described_class.ci_environment?).to be false
      end
    end

    it 'returns false when no CI variables are set' do
      with_env(GITHUB_ACTIONS: nil, CI: nil) do
        expect(described_class.ci_environment?).to be false
      end
    end

    it 'prioritizes GITHUB_ACTIONS over CI' do
      with_env(GITHUB_ACTIONS: 'true', CI: 'false') do
        expect(described_class.ci_environment?).to be true
      end
    end
  end

  describe '.production_environment?' do
    it 'returns true when environment is production' do
      allow(described_class).to receive(:environment).and_return('production')
      expect(described_class.production_environment?).to be true
    end

    it 'returns false when environment is not production' do
      allow(described_class).to receive(:environment).and_return('test')
      expect(described_class.production_environment?).to be false
    end

    it 'returns false when environment is development' do
      allow(described_class).to receive(:environment).and_return('development')
      expect(described_class.production_environment?).to be false
    end
  end

  describe '.development_environment?' do
    it 'returns true when environment is development' do
      allow(described_class).to receive(:environment).and_return('development')
      expect(described_class.development_environment?).to be true
    end

    it 'returns false when environment is not development' do
      allow(described_class).to receive(:environment).and_return('test')
      expect(described_class.development_environment?).to be false
    end

    it 'returns false when environment is production' do
      allow(described_class).to receive(:environment).and_return('production')
      expect(described_class.development_environment?).to be false
    end
  end

  describe '.get' do
    it 'returns environment variable value when set' do
      with_env(PLAYWRIGHT_BROWSER: 'chromium') do
        expect(described_class.get('PLAYWRIGHT_BROWSER')).to eq('chromium')
      end
    end

    it 'returns default when environment variable is not set' do
      with_env(MISSING_VAR: nil) do
        expect(described_class.get('MISSING_VAR', 'default_value')).to eq('default_value')
      end
    end

    it 'returns nil when environment variable is not set and no default provided' do
      with_env(MISSING_VAR: nil) do
        expect(described_class.get('MISSING_VAR')).to be_nil
      end
    end

    it 'returns empty string when environment variable is empty' do
      with_env(EMPTY_VAR: '') do
        expect(described_class.get('EMPTY_VAR', 'default')).to eq('')
      end
    end

    it 'prioritizes environment variable over default' do
      with_env(SOME_VAR: 'actual_value') do
        expect(described_class.get('SOME_VAR', 'default_value')).to eq('actual_value')
      end
    end

    it 'handles multiple calls with different variables' do
      with_env(VAR1: 'value1', VAR2: 'value2') do
        expect(described_class.get('VAR1')).to eq('value1')
        expect(described_class.get('VAR2')).to eq('value2')
        expect(described_class.get('VAR3', 'default')).to eq('default')
      end
    end

    it 'handles numeric default values' do
      with_env(MISSING_NUM: nil) do
        expect(described_class.get('MISSING_NUM', 42)).to eq(42)
      end
    end

    it 'handles boolean default values' do
      with_env(MISSING_BOOL: nil) do
        expect(described_class.get('MISSING_BOOL', true)).to be true
      end
    end
  end

  describe 'integration tests' do
    it 'works correctly in test environment' do
      with_env(RACK_ENV: 'test', CI: nil, GITHUB_ACTIONS: nil) do
        hide_const('Rails') if defined?(Rails)

        expect(described_class.environment).to eq('test')
        expect(described_class.test_environment?).to be true
        expect(described_class.ci_environment?).to be false
        expect(described_class.production_environment?).to be false
        expect(described_class.development_environment?).to be false
      end
    end

    it 'works correctly in CI environment' do
      with_env(RACK_ENV: 'test', GITHUB_ACTIONS: 'true') do
        hide_const('Rails') if defined?(Rails)

        expect(described_class.environment).to eq('test')
        expect(described_class.test_environment?).to be true
        expect(described_class.ci_environment?).to be true
      end
    end

    it 'works correctly in local development' do
      with_env(RACK_ENV: 'development', CI: nil, GITHUB_ACTIONS: nil) do
        hide_const('Rails') if defined?(Rails)

        expect(described_class.environment).to eq('development')
        expect(described_class.development_environment?).to be true
        expect(described_class.test_environment?).to be false
        expect(described_class.ci_environment?).to be false
      end
    end
  end

  describe 'edge cases' do
    it 'handles case sensitivity correctly' do
      with_env(CI: 'True') do
        # Should be case-sensitive ('true' vs 'True')
        expect(described_class.ci_environment?).to be false
      end
    end

    it 'handles whitespace in environment variables' do
      with_env(RACK_ENV: '  test  ') do
        hide_const('Rails') if defined?(Rails)

        expect(described_class.environment).to eq('  test  ')
      end
    end

    it 'handles special characters in get method' do
      with_env(SPECIAL_VAR: 'value/with:special*chars') do
        expect(described_class.get('SPECIAL_VAR')).to eq('value/with:special*chars')
      end
    end
  end
end
