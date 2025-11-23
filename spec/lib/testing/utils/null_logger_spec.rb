# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/testing/utils/null_logger'

RSpec.describe Testing::Utils::NullLogger do
  subject(:logger) { described_class.new }

  describe '#debug' do
    it 'is callable without arguments' do
      expect { logger.debug }.not_to raise_error
    end

    it 'is callable with string argument' do
      expect { logger.debug('debug message') }.not_to raise_error
    end

    it 'is callable with multiple arguments' do
      expect { logger.debug('message', key: 'value', status: 200) }.not_to raise_error
    end

    it 'returns nil' do
      expect(logger.debug('message')).to be_nil
    end

    it 'does not output anything' do
      expect { logger.debug('debug message') }.not_to output.to_stdout
    end
  end

  describe '#info' do
    it 'is callable without arguments' do
      expect { logger.info }.not_to raise_error
    end

    it 'is callable with string argument' do
      expect { logger.info('info message') }.not_to raise_error
    end

    it 'is callable with multiple arguments' do
      expect { logger.info('message', metadata: { user: 'test' }) }.not_to raise_error
    end

    it 'returns nil' do
      expect(logger.info('message')).to be_nil
    end

    it 'does not output anything' do
      expect { logger.info('info message') }.not_to output.to_stdout
    end
  end

  describe '#warn' do
    it 'is callable without arguments' do
      expect { logger.warn }.not_to raise_error
    end

    it 'is callable with string argument' do
      expect { logger.warn('warning message') }.not_to raise_error
    end

    it 'is callable with multiple arguments' do
      expect { logger.warn('message', error_code: 404) }.not_to raise_error
    end

    it 'returns nil' do
      expect(logger.warn('message')).to be_nil
    end

    it 'does not output anything' do
      expect { logger.warn('warning message') }.not_to output.to_stderr
    end
  end

  describe '#error' do
    it 'is callable without arguments' do
      expect { logger.error }.not_to raise_error
    end

    it 'is callable with string argument' do
      expect { logger.error('error message') }.not_to raise_error
    end

    it 'is callable with multiple arguments' do
      expect { logger.error('message', exception: StandardError.new) }.not_to raise_error
    end

    it 'returns nil' do
      expect(logger.error('message')).to be_nil
    end

    it 'does not output anything' do
      expect { logger.error('error message') }.not_to output.to_stderr
    end
  end

  describe '#fatal' do
    it 'is callable without arguments' do
      expect { logger.fatal }.not_to raise_error
    end

    it 'is callable with string argument' do
      expect { logger.fatal('fatal message') }.not_to raise_error
    end

    it 'is callable with multiple arguments' do
      expect { logger.fatal('message', backtrace: []) }.not_to raise_error
    end

    it 'returns nil' do
      expect(logger.fatal('message')).to be_nil
    end

    it 'does not output anything' do
      expect { logger.fatal('fatal message') }.not_to output.to_stderr
    end
  end

  describe 'as drop-in replacement for standard logger' do
    it 'implements all standard logger methods' do
      expect(logger).to respond_to(:debug)
      expect(logger).to respond_to(:info)
      expect(logger).to respond_to(:warn)
      expect(logger).to respond_to(:error)
      expect(logger).to respond_to(:fatal)
    end

    it 'accepts same arguments as Rails.logger' do
      # Simulate Rails.logger usage patterns
      expect { logger.debug { 'lazy message' } }.not_to raise_error
      expect { logger.info('User logged in', user_id: 123) }.not_to raise_error
      expect { logger.warn('Deprecated method called') }.not_to raise_error
      expect { logger.error(StandardError.new('Test error')) }.not_to raise_error
      expect { logger.fatal('System shutdown') }.not_to raise_error
    end

    it 'can be used in dependency injection' do
      # Simulate class that accepts logger
      service_class = Class.new do
        attr_reader :logger

        def initialize(logger:)
          @logger = logger
        end

        def perform
          logger.info('Performing action')
          logger.debug('Debug info')
        end
      end

      service = service_class.new(logger: logger)
      expect { service.perform }.not_to raise_error
    end
  end

  describe 'with various argument types' do
    it 'handles string arguments' do
      expect { logger.info('string') }.not_to raise_error
    end

    it 'handles integer arguments' do
      expect { logger.debug(42) }.not_to raise_error
    end

    it 'handles hash arguments' do
      expect { logger.info(user: 'test', action: 'login') }.not_to raise_error
    end

    it 'handles array arguments' do
      expect { logger.warn(['error1', 'error2']) }.not_to raise_error
    end

    it 'handles exception arguments' do
      exception = StandardError.new('Test error')
      expect { logger.error(exception) }.not_to raise_error
    end

    it 'handles nil arguments' do
      expect { logger.debug(nil) }.not_to raise_error
    end

    it 'handles block arguments' do
      expect { logger.info { 'lazy evaluation' } }.not_to raise_error
    end

    it 'handles mixed arguments' do
      expect { logger.warn('message', { key: 'value' }, 123, nil) }.not_to raise_error
    end
  end

  describe 'thread safety' do
    it 'can be used from multiple threads' do
      threads = 10.times.map do
        Thread.new do
          100.times do |i|
            logger.info("Thread message #{i}")
            logger.debug("Debug #{i}")
            logger.error("Error #{i}")
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end

  describe 'memory efficiency' do
    it 'does not accumulate messages' do
      # Log many messages
      1000.times do |i|
        logger.debug("Message #{i}")
        logger.info("Info #{i}")
        logger.error("Error #{i}")
      end

      # NullLogger should not store anything
      # This test verifies no memory leak
      expect(logger.instance_variables).to be_empty
    end
  end

  describe 'performance' do
    it 'is fast (no-op implementation)' do
      start_time = Time.now

      10_000.times do
        logger.debug('message')
        logger.info('message')
        logger.warn('message')
        logger.error('message')
        logger.fatal('message')
      end

      elapsed = Time.now - start_time

      # Should complete very quickly (under 1 second for 50,000 calls)
      expect(elapsed).to be < 1.0
    end
  end

  describe 'instance creation' do
    it 'can create multiple instances' do
      logger1 = described_class.new
      logger2 = described_class.new

      expect(logger1).not_to be(logger2)
    end

    it 'instances are independent' do
      logger1 = described_class.new
      logger2 = described_class.new

      # Both loggers should work independently without affecting each other
      expect { logger1.info('message') }.not_to raise_error
      expect { logger2.info('message') }.not_to raise_error
    end
  end

  describe 'nil object pattern compliance' do
    it 'never raises exceptions' do
      # Try to break it with various edge cases
      expect { logger.debug(nil) }.not_to raise_error
      expect { logger.info }.not_to raise_error
      expect { logger.warn([], {}, nil, 123) }.not_to raise_error
      expect { logger.error { raise 'Should not be called' } }.not_to raise_error
      expect { logger.fatal(StandardError.new) }.not_to raise_error
    end

    it 'always returns nil' do
      expect(logger.debug('test')).to be_nil
      expect(logger.info('test')).to be_nil
      expect(logger.warn('test')).to be_nil
      expect(logger.error('test')).to be_nil
      expect(logger.fatal('test')).to be_nil
    end

    it 'has no side effects' do
      # Calling methods should not change any state
      logger.debug('test')
      expect(logger.instance_variables).to be_empty

      logger.info('test')
      expect(logger.instance_variables).to be_empty

      logger.error('test')
      expect(logger.instance_variables).to be_empty
    end
  end
end
