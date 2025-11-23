# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/testing/utils/string_utils'

RSpec.describe Testing::Utils::StringUtils do
  describe '.sanitize_filename' do
    it 'preserves alphanumeric characters' do
      result = described_class.sanitize_filename('Test123ABC')
      expect(result).to eq('Test123ABC')
    end

    it 'preserves hyphens' do
      result = described_class.sanitize_filename('test-file-name')
      expect(result).to eq('test-file-name')
    end

    it 'preserves underscores' do
      result = described_class.sanitize_filename('test_file_name')
      expect(result).to eq('test_file_name')
    end

    it 'preserves dots' do
      result = described_class.sanitize_filename('file.name.txt')
      expect(result).to eq('file.name.txt')
    end

    it 'replaces forward slashes with underscores' do
      result = described_class.sanitize_filename('path/to/file')
      expect(result).to eq('path_to_file')
    end

    it 'replaces backslashes with underscores' do
      result = described_class.sanitize_filename('path\\to\\file')
      expect(result).to eq('path_to_file')
    end

    it 'replaces colons with underscores' do
      result = described_class.sanitize_filename('User Login: Test')
      expect(result).to eq('User_Login__Test')
    end

    it 'replaces asterisks with underscores' do
      result = described_class.sanitize_filename('file*name')
      expect(result).to eq('file_name')
    end

    it 'replaces question marks with underscores' do
      result = described_class.sanitize_filename('what?where?')
      expect(result).to eq('what_where_')
    end

    it 'replaces double quotes with underscores' do
      result = described_class.sanitize_filename('"quoted"')
      expect(result).to eq('_quoted_')
    end

    it 'replaces less-than signs with underscores' do
      result = described_class.sanitize_filename('a<b')
      expect(result).to eq('a_b')
    end

    it 'replaces greater-than signs with underscores' do
      result = described_class.sanitize_filename('a>b')
      expect(result).to eq('a_b')
    end

    it 'replaces pipes with underscores' do
      result = described_class.sanitize_filename('a|b')
      expect(result).to eq('a_b')
    end

    it 'replaces spaces with underscores' do
      result = described_class.sanitize_filename('test file name')
      expect(result).to eq('test_file_name')
    end

    it 'replaces multiple special characters' do
      result = described_class.sanitize_filename('User Login: Test #1')
      expect(result).to eq('User_Login__Test__1')
    end

    it 'prevents path traversal attacks' do
      result = described_class.sanitize_filename('../etc/passwd')
      # Dots preserved, slashes become underscores
      expect(result).to eq('.._etc_passwd')
    end

    it 'prevents Windows path traversal' do
      result = described_class.sanitize_filename('..\\windows\\system32')
      # Dots preserved, backslashes become underscores
      expect(result).to eq('.._windows_system32')
    end

    it 'handles empty string' do
      result = described_class.sanitize_filename('')
      expect(result).to eq('')
    end

    it 'handles string with only special characters' do
      result = described_class.sanitize_filename('!@#$%^&*()')
      expect(result).to eq('__________')
    end

    it 'handles Unicode characters' do
      result = described_class.sanitize_filename('テスト')
      # Unicode characters are replaced with underscores
      expect(result).not_to include('テ')
      expect(result).not_to include('ス')
      expect(result).not_to include('ト')
    end

    it 'handles emoji' do
      result = described_class.sanitize_filename('test 🎉 emoji')
      # Emoji and spaces are replaced with underscores
      expect(result).not_to include('🎉')
      expect(result).to start_with('test_')
      expect(result).to end_with('_emoji')
    end

    it 'converts nil to empty string' do
      result = described_class.sanitize_filename(nil)
      expect(result).to eq('')
    end

    it 'handles numbers' do
      result = described_class.sanitize_filename(12_345)
      expect(result).to eq('12345')
    end
  end

  describe '.generate_artifact_name' do
    it 'sanitizes test name' do
      result = described_class.generate_artifact_name('User Login: Test')
      expect(result).to eq('User_Login__Test')
    end

    it 'appends index when provided' do
      result = described_class.generate_artifact_name('User Login', 2)
      expect(result).to eq('User_Login_2')
    end

    it 'does not append index when nil' do
      result = described_class.generate_artifact_name('User Login', nil)
      expect(result).to eq('User_Login')
    end

    it 'handles index 0' do
      result = described_class.generate_artifact_name('Test', 0)
      expect(result).to eq('Test_0')
    end

    it 'handles large index numbers' do
      result = described_class.generate_artifact_name('Test', 12_345)
      expect(result).to eq('Test_12345')
    end

    it 'sanitizes before appending index' do
      result = described_class.generate_artifact_name('Test/Name', 1)
      expect(result).to eq('Test_Name_1')
    end

    it 'handles empty test name' do
      result = described_class.generate_artifact_name('', 1)
      expect(result).to eq('_1')
    end

    it 'handles test name with path traversal' do
      result = described_class.generate_artifact_name('../test', 1)
      # Dots preserved, slashes become underscores
      expect(result).to eq('.._test_1')
    end
  end

  describe '.truncate_filename' do
    it 'returns filename as-is when under max length' do
      short_name = 'short.txt'
      result = described_class.truncate_filename(short_name)
      expect(result).to eq('short.txt')
    end

    it 'truncates long filename while preserving extension' do
      long_name = "#{'a' * 300}.png"
      result = described_class.truncate_filename(long_name, 255)

      expect(result.length).to eq(255)
      expect(result).to end_with('.png')
      expect(result).to include('...')
    end

    it 'uses default max length of 255' do
      long_name = "#{'a' * 300}.txt"
      result = described_class.truncate_filename(long_name)

      expect(result.length).to eq(255)
    end

    it 'accepts custom max length' do
      name = "#{'a' * 50}.txt"
      result = described_class.truncate_filename(name, 20)

      expect(result.length).to eq(20)
      expect(result).to end_with('.txt')
    end

    it 'preserves file extension' do
      long_name = "#{'a' * 300}.jpeg"
      result = described_class.truncate_filename(long_name, 255)

      expect(result).to end_with('.jpeg')
    end

    it 'adds ellipsis when truncating' do
      long_name = "#{'a' * 300}.txt"
      result = described_class.truncate_filename(long_name, 255)

      expect(result).to include('...')
    end

    it 'handles filename without extension' do
      long_name = 'a' * 300
      result = described_class.truncate_filename(long_name, 255)

      expect(result.length).to eq(255)
      expect(result).to include('...')
    end

    it 'handles very long extensions' do
      name = 'test.extension_very_long'
      result = described_class.truncate_filename(name, 20)

      # When extension is too long, truncate everything
      expect(result.length).to eq(20)
    end

    it 'handles edge case where max_length equals current length' do
      name = 'test.txt'
      result = described_class.truncate_filename(name, name.length)

      expect(result).to eq('test.txt')
    end

    it 'handles filename with multiple dots' do
      long_name = "#{'a' * 300}.tar.gz"
      result = described_class.truncate_filename(long_name, 255)

      expect(result.length).to eq(255)
      expect(result).to end_with('.gz') # Only last extension is preserved
    end

    it 'handles very short max length' do
      name = 'filename.txt'
      result = described_class.truncate_filename(name, 10)

      expect(result.length).to eq(10)
    end

    it 'handles empty filename' do
      result = described_class.truncate_filename('', 255)
      expect(result).to eq('')
    end

    it 'calculates available length correctly' do
      # Max 20, extension .txt (4), ellipsis ... (3)
      # Available for basename: 20 - 4 - 3 = 13
      name = "#{'a' * 30}.txt"
      result = described_class.truncate_filename(name, 20)

      expect(result.length).to eq(20)
      expect(result).to match(/^a{13}\.\.\.\.txt$/)
    end
  end

  describe 'integration tests' do
    it 'sanitize_filename and truncate_filename work together' do
      unsafe_long_name = "../#{'a' * 300}/test.txt"

      sanitized = described_class.sanitize_filename(unsafe_long_name)
      truncated = described_class.truncate_filename(sanitized, 255)

      expect(truncated.length).to eq(255)
      expect(truncated).not_to include('/')
    end

    it 'generate_artifact_name produces safe filenames' do
      test_name = 'User Login: Test #1 (Retry)'
      artifact_name = described_class.generate_artifact_name(test_name, 2)

      expect(artifact_name).to match(/^[\w\-._]+$/)
      expect(artifact_name).to end_with('_2')
    end

    it 'all methods handle empty input' do
      expect(described_class.sanitize_filename('')).to eq('')
      expect(described_class.generate_artifact_name('')).to eq('')
      expect(described_class.truncate_filename('')).to eq('')
    end

    it 'all methods handle nil input' do
      expect(described_class.sanitize_filename(nil)).to eq('')
      expect(described_class.generate_artifact_name(nil)).to eq('')
    end
  end

  describe 'security tests' do
    it 'prevents directory traversal with ../' do
      malicious = '../../../etc/passwd'
      result = described_class.sanitize_filename(malicious)

      expect(result).not_to include('/')
      # Dots and hyphens are preserved, slashes become underscores
      expect(result).to eq('.._.._.._etc_passwd')
    end

    it 'prevents directory traversal with ..\\' do
      malicious = '..\\..\\windows\\system32'
      result = described_class.sanitize_filename(malicious)

      expect(result).not_to include('\\')
      # Dots and hyphens are preserved, backslashes become underscores
      expect(result).to eq('.._.._windows_system32')
    end

    it 'prevents null byte injection' do
      malicious = "test\x00.txt"
      result = described_class.sanitize_filename(malicious)

      expect(result).not_to include("\x00")
    end

    it 'prevents command injection' do
      malicious = 'test; rm -rf /'
      result = described_class.sanitize_filename(malicious)

      # Semicolon and slashes become underscores, hyphens are preserved
      expect(result).to eq('test__rm_-rf__')
    end
  end

  describe 'constants' do
    it 'defines MAX_FILENAME_LENGTH' do
      expect(described_class::MAX_FILENAME_LENGTH).to eq(255)
    end
  end

  describe 'return types' do
    it 'sanitize_filename returns String' do
      expect(described_class.sanitize_filename('test')).to be_a(String)
    end

    it 'generate_artifact_name returns String' do
      expect(described_class.generate_artifact_name('test')).to be_a(String)
    end

    it 'truncate_filename returns String' do
      expect(described_class.truncate_filename('test')).to be_a(String)
    end
  end
end
