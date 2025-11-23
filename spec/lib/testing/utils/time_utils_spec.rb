# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/testing/utils/time_utils'

RSpec.describe Testing::Utils::TimeUtils do
  let(:fixed_time) { Time.new(2025, 11, 23, 14, 30, 52, '+09:00') }

  describe '.format_for_filename' do
    it 'returns filename-safe timestamp format' do
      result = described_class.format_for_filename(fixed_time)
      expect(result).to eq('20251123-143052')
    end

    it 'uses Time.now when no parameter provided' do
      result = described_class.format_for_filename
      expect(result).to match(/^\d{8}-\d{6}$/)
    end

    it 'does not contain colons' do
      result = described_class.format_for_filename(fixed_time)
      expect(result).not_to include(':')
    end

    it 'does not contain slashes' do
      result = described_class.format_for_filename(fixed_time)
      expect(result).not_to include('/')
    end

    it 'does not contain spaces' do
      result = described_class.format_for_filename(fixed_time)
      expect(result).not_to include(' ')
    end

    it 'handles different times correctly' do
      time1 = Time.new(2025, 1, 1, 0, 0, 0)
      time2 = Time.new(2025, 12, 31, 23, 59, 59)

      expect(described_class.format_for_filename(time1)).to eq('20250101-000000')
      expect(described_class.format_for_filename(time2)).to eq('20251231-235959')
    end

    it 'handles midnight correctly' do
      midnight = Time.new(2025, 6, 15, 0, 0, 0)
      result = described_class.format_for_filename(midnight)
      expect(result).to eq('20250615-000000')
    end

    it 'handles noon correctly' do
      noon = Time.new(2025, 6, 15, 12, 0, 0)
      result = described_class.format_for_filename(noon)
      expect(result).to eq('20250615-120000')
    end

    it 'pads single-digit values with zeros' do
      time = Time.new(2025, 1, 9, 5, 3, 7)
      result = described_class.format_for_filename(time)
      expect(result).to eq('20250109-050307')
    end
  end

  describe '.format_iso8601' do
    it 'returns ISO 8601 formatted timestamp' do
      result = described_class.format_iso8601(fixed_time)
      expect(result).to eq('2025-11-23T14:30:52+09:00')
    end

    it 'uses Time.now when no parameter provided' do
      result = described_class.format_iso8601
      expect(result).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$/)
    end

    it 'includes timezone information' do
      result = described_class.format_iso8601(fixed_time)
      expect(result).to include('+09:00')
    end

    it 'handles different timezones' do
      utc_time = Time.new(2025, 11, 23, 14, 30, 52, '+00:00')
      result = described_class.format_iso8601(utc_time)
      expect(result).to include('+00:00')
    end

    it 'is a valid ISO 8601 format' do
      result = described_class.format_iso8601(fixed_time)
      parsed_time = Time.iso8601(result)
      expect(parsed_time).to be_a(Time)
    end

    it 'preserves original time when parsed back' do
      result = described_class.format_iso8601(fixed_time)
      parsed_time = Time.iso8601(result)
      expect(parsed_time).to eq(fixed_time)
    end
  end

  describe '.format_human' do
    it 'returns human-readable timestamp' do
      result = described_class.format_human(fixed_time)
      expect(result).to eq('2025-11-23 14:30:52')
    end

    it 'uses Time.now when no parameter provided' do
      result = described_class.format_human
      expect(result).to match(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/)
    end

    it 'uses YYYY-MM-DD format for date' do
      result = described_class.format_human(fixed_time)
      expect(result).to start_with('2025-11-23')
    end

    it 'uses HH:MM:SS format for time' do
      result = described_class.format_human(fixed_time)
      expect(result).to end_with('14:30:52')
    end

    it 'handles different times correctly' do
      time1 = Time.new(2025, 1, 1, 0, 0, 0)
      time2 = Time.new(2025, 12, 31, 23, 59, 59)

      expect(described_class.format_human(time1)).to eq('2025-01-01 00:00:00')
      expect(described_class.format_human(time2)).to eq('2025-12-31 23:59:59')
    end

    it 'does not include timezone information' do
      result = described_class.format_human(fixed_time)
      expect(result).not_to match(/[+-]\d{2}:\d{2}/)
    end
  end

  describe '.generate_correlation_id' do
    it 'returns unique correlation ID' do
      id1 = described_class.generate_correlation_id
      id2 = described_class.generate_correlation_id

      expect(id1).not_to eq(id2)
    end

    it 'includes default prefix' do
      result = described_class.generate_correlation_id
      expect(result).to start_with('test-run-')
    end

    it 'includes custom prefix when provided' do
      result = described_class.generate_correlation_id('rspec')
      expect(result).to start_with('rspec-')
    end

    it 'includes timestamp in filename format' do
      result = described_class.generate_correlation_id
      # Format: prefix-YYYYMMDD-HHMMSS-XXXXXX
      expect(result).to match(/^test-run-\d{8}-\d{6}-[a-f0-9]{6}$/)
    end

    it 'includes 6-character random hex' do
      result = described_class.generate_correlation_id
      # Extract hex part
      hex = result.split('-').last
      expect(hex).to match(/^[a-f0-9]{6}$/)
    end

    it 'generates multiple unique IDs' do
      ids = 10.times.map { described_class.generate_correlation_id }
      expect(ids.uniq.length).to eq(10)
    end

    it 'handles various prefix formats' do
      prefixes = ['test', 'rspec', 'playwright', 'ci-run', 'test_run']

      prefixes.each do |prefix|
        result = described_class.generate_correlation_id(prefix)
        expect(result).to start_with("#{prefix}-")
      end
    end

    it 'works with empty prefix' do
      result = described_class.generate_correlation_id('')
      # Format: -YYYYMMDD-HHMMSS-XXXXXX
      expect(result).to match(/^-\d{8}-\d{6}-[a-f0-9]{6}$/)
    end

    it 'generates IDs that can be used as filenames' do
      result = described_class.generate_correlation_id
      # Should not contain unsafe characters
      expect(result).not_to match(%r{[/\\:*?"<>|]})
    end

    it 'ensures uniqueness even when called rapidly' do
      ids = []
      100.times do
        ids << described_class.generate_correlation_id
      end

      expect(ids.uniq.length).to eq(100)
    end
  end

  describe 'integration tests' do
    it 'all formats work with the same time object' do
      time = Time.new(2025, 6, 15, 12, 30, 45)

      filename_format = described_class.format_for_filename(time)
      iso_format = described_class.format_iso8601(time)
      human_format = described_class.format_human(time)

      expect(filename_format).to eq('20250615-123045')
      expect(iso_format).to match(/^2025-06-15T12:30:45/)
      expect(human_format).to eq('2025-06-15 12:30:45')
    end

    it 'correlation ID includes current timestamp' do
      before_time = Time.now
      correlation_id = described_class.generate_correlation_id

      # Extract timestamp from correlation ID
      parts = correlation_id.split('-')
      # parts: ['test', 'run', 'YYYYMMDD', 'HHMMSS', 'XXXXXX']
      timestamp_str = "#{parts[2]}-#{parts[3]}"

      # Parse timestamp
      timestamp = Time.strptime(timestamp_str, '%Y%m%d-%H%M%S')

      # Should be within 1 second
      expect(timestamp).to be_within(1).of(before_time)
    end
  end

  describe 'edge cases' do
    it 'handles leap year dates' do
      leap_day = Time.new(2024, 2, 29, 12, 0, 0)

      expect(described_class.format_for_filename(leap_day)).to eq('20240229-120000')
      expect(described_class.format_human(leap_day)).to eq('2024-02-29 12:00:00')
    end

    it 'handles year boundaries' do
      new_year = Time.new(2026, 1, 1, 0, 0, 0)

      expect(described_class.format_for_filename(new_year)).to eq('20260101-000000')
      expect(described_class.format_human(new_year)).to eq('2026-01-01 00:00:00')
    end

    it 'handles far future dates' do
      future = Time.new(2099, 12, 31, 23, 59, 59)

      expect(described_class.format_for_filename(future)).to eq('20991231-235959')
      expect(described_class.format_human(future)).to eq('2099-12-31 23:59:59')
    end

    it 'handles past dates' do
      past = Time.new(2000, 1, 1, 0, 0, 0)

      expect(described_class.format_for_filename(past)).to eq('20000101-000000')
      expect(described_class.format_human(past)).to eq('2000-01-01 00:00:00')
    end
  end

  describe 'return types' do
    it 'format_for_filename returns String' do
      expect(described_class.format_for_filename(fixed_time)).to be_a(String)
    end

    it 'format_iso8601 returns String' do
      expect(described_class.format_iso8601(fixed_time)).to be_a(String)
    end

    it 'format_human returns String' do
      expect(described_class.format_human(fixed_time)).to be_a(String)
    end

    it 'generate_correlation_id returns String' do
      expect(described_class.generate_correlation_id).to be_a(String)
    end
  end
end
