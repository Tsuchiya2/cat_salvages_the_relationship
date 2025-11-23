# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/testing/retry_policy'
require_relative '../../../lib/testing/utils/null_logger'

RSpec.describe Testing::RetryPolicy do
  let(:mock_logger) { instance_double(Logger) }
  let(:retry_policy) do
    described_class.new(
      max_attempts: 3,
      backoff_multiplier: 2,
      initial_delay: 2,
      logger: mock_logger,
      error_handling: { retryable: [Errno::ECONNREFUSED, Errno::ETIMEDOUT],
                        non_retryable: [] }
    )
  end

  before do
    allow(mock_logger).to receive(:warn)
    allow(mock_logger).to receive(:info)
  end

  describe '#initialize' do
    it 'accepts max_attempts parameter' do
      policy = described_class.new(
        max_attempts: 5,
        backoff_multiplier: 2,
        initial_delay: 1,
        logger: mock_logger,
        error_handling: { retryable: [],
                          non_retryable: [] }
      )

      expect(policy.max_attempts).to eq(5)
    end

    it 'accepts backoff_multiplier parameter' do
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 3,
        initial_delay: 1,
        logger: mock_logger,
        error_handling: { retryable: [],
                          non_retryable: [] }
      )

      expect(policy.backoff_multiplier).to eq(3)
    end

    it 'accepts initial_delay parameter' do
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 2,
        initial_delay: 5,
        logger: mock_logger,
        error_handling: { retryable: [],
                          non_retryable: [] }
      )

      expect(policy.initial_delay).to eq(5)
    end

    it 'accepts logger parameter' do
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 2,
        initial_delay: 1,
        logger: mock_logger,
        error_handling: { retryable: [],
                          non_retryable: [] }
      )

      expect(policy.logger).to eq(mock_logger)
    end

    it 'uses NullLogger as default' do
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 2,
        initial_delay: 1,
        error_handling: { retryable: [],
                          non_retryable: [] }
      )

      expect(policy.logger).to be_a(Testing::Utils::NullLogger)
    end

    it 'accepts retryable_errors list' do
      errors = [Errno::ECONNREFUSED, Errno::ETIMEDOUT]
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 2,
        initial_delay: 1,
        logger: mock_logger,
        error_handling: { retryable: errors, non_retryable: [] }
      )

      expect(policy.retryable_errors).to eq(errors)
    end

    it 'accepts non_retryable_errors list' do
      errors = [ArgumentError, TypeError]
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 2,
        initial_delay: 1,
        logger: mock_logger,
        error_handling: { retryable: [], non_retryable: errors }
      )

      expect(policy.non_retryable_errors).to include(*errors)
      expect(policy.non_retryable_errors).to include(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe '#execute' do
    context 'with successful block execution' do
      it 'executes block once and returns result' do
        execution_count = 0

        result = retry_policy.execute do
          execution_count += 1
          'success'
        end

        expect(result).to eq('success')
        expect(execution_count).to eq(1)
      end

      it 'does not log retry attempts' do
        expect(mock_logger).not_to receive(:warn)

        retry_policy.execute do
          'success'
        end
      end
    end

    context 'with retryable errors' do
      it 'retries on retryable errors' do
        execution_count = 0

        result = retry_policy.execute do
          execution_count += 1
          raise Errno::ECONNREFUSED if execution_count < 3

          'success'
        end

        expect(result).to eq('success')
        expect(execution_count).to eq(3)
      end

      it 'logs each retry attempt' do
        execution_count = 0

        expect(mock_logger).to receive(:warn).twice

        retry_policy.execute do
          execution_count += 1
          raise Errno::ECONNREFUSED if execution_count < 3

          'success'
        end
      end

      it 'includes attempt number in log' do
        execution_count = 0

        expect(mock_logger).to receive(:warn) do |message|
          expect(message).to match(/attempt.*1/i)
        end

        expect(mock_logger).to receive(:warn) do |message|
          expect(message).to match(/attempt.*2/i)
        end

        retry_policy.execute do
          execution_count += 1
          raise Errno::ECONNREFUSED if execution_count < 3

          'success'
        end
      end

      it 'includes error message in log' do
        execution_count = 0

        expect(mock_logger).to receive(:warn) do |message|
          expect(message).to include('ECONNREFUSED').or include('Connection refused')
        end.at_least(:once)

        retry_policy.execute do
          execution_count += 1
          raise Errno::ECONNREFUSED if execution_count < 3

          'success'
        end
      end

      it 'waits with exponential backoff between retries' do
        execution_count = 0
        retry_times = []

        retry_policy.execute do
          retry_times << Time.zone.now if execution_count > 0
          execution_count += 1
          raise Errno::ECONNREFUSED if execution_count < 3

          'success'
        end

        # Verify delays (approximately 2s, 4s)
        if retry_times.size >= 2
          delay1 = retry_times[1] - retry_times[0]
          expect(delay1).to be >= 1.8 # Allow some tolerance
        end
      end

      it 'raises error after max_attempts exceeded' do
        execution_count = 0

        expect do
          retry_policy.execute do
            execution_count += 1
            raise Errno::ECONNREFUSED, 'Connection refused'
          end
        end.to raise_error(Errno::ECONNREFUSED, /Connection refused/)

        expect(execution_count).to eq(3) # max_attempts
      end
    end

    context 'with non-retryable errors' do
      let(:retry_policy) do
        described_class.new(
          max_attempts: 3,
          backoff_multiplier: 2,
          initial_delay: 0.1,
          logger: mock_logger,
          error_handling: { retryable: [Errno::ECONNREFUSED],
                            non_retryable: [ArgumentError, TypeError] }
        )
      end

      it 'does not retry on non-retryable errors' do
        execution_count = 0

        expect do
          retry_policy.execute do
            execution_count += 1
            raise ArgumentError, 'Invalid argument'
          end
        end.to raise_error(ArgumentError, 'Invalid argument')

        expect(execution_count).to eq(1)
      end

      it 'does not log retry attempts for non-retryable errors' do
        expect(mock_logger).not_to receive(:warn)

        expect do
          retry_policy.execute do
            raise ArgumentError, 'Invalid argument'
          end
        end.to raise_error(ArgumentError)
      end
    end

    context 'with RSpec expectation failures (non-retryable)' do
      let(:retry_policy) do
        described_class.new(
          max_attempts: 3,
          backoff_multiplier: 2,
          initial_delay: 0.1,
          logger: mock_logger,
          error_handling: { retryable: [StandardError],
                            non_retryable: [] }
        )
      end

      it 'does not retry RSpec expectation failures' do
        execution_count = 0

        # Simulate RSpec expectation failure
        expectation_error = Class.new(StandardError) do
          def self.name
            'RSpec::Expectations::ExpectationNotMetError'
          end
        end

        # Add to non_retryable_errors
        retry_policy_with_rspec = described_class.new(
          max_attempts: 3,
          backoff_multiplier: 2,
          initial_delay: 0.1,
          logger: mock_logger,
          error_handling: { retryable: [StandardError],
                            non_retryable: [expectation_error] }
        )

        expect do
          retry_policy_with_rspec.execute do
            execution_count += 1
            raise expectation_error, 'Expected value to be true'
          end
        end.to raise_error(expectation_error)

        expect(execution_count).to eq(1)
      end
    end

    context 'with Minitest assertion failures (non-retryable)' do
      let(:retry_policy) do
        described_class.new(
          max_attempts: 3,
          backoff_multiplier: 2,
          initial_delay: 0.1,
          logger: mock_logger,
          error_handling: { retryable: [StandardError],
                            non_retryable: [] }
        )
      end

      it 'does not retry Minitest assertion failures' do
        execution_count = 0

        # Simulate Minitest assertion failure
        assertion_error = Class.new(StandardError) do
          def self.name
            'Minitest::Assertion'
          end
        end

        # Add to non_retryable_errors
        retry_policy_with_minitest = described_class.new(
          max_attempts: 3,
          backoff_multiplier: 2,
          initial_delay: 0.1,
          logger: mock_logger,
          error_handling: { retryable: [StandardError],
                            non_retryable: [assertion_error] }
        )

        expect do
          retry_policy_with_minitest.execute do
            execution_count += 1
            raise assertion_error, 'Expected true but got false'
          end
        end.to raise_error(assertion_error)

        expect(execution_count).to eq(1)
      end
    end
  end

  describe 'backoff calculation' do
    let(:retry_policy) do
      described_class.new(
        max_attempts: 5,
        backoff_multiplier: 2,
        initial_delay: 2,
        logger: mock_logger,
        error_handling: { retryable: [StandardError],
                          non_retryable: [] }
      )
    end

    it 'calculates exponential backoff correctly' do
      execution_count = 0
      start_times = []

      retry_policy.execute do
        start_times << Time.zone.now
        execution_count += 1
        raise StandardError if execution_count < 4

        'success'
      end

      # Verify delays: ~2s, ~4s, ~8s
      delays = start_times.each_cons(2).map { |t1, t2| t2 - t1 }

      expect(delays[0]).to be_within(0.5).of(2.0)  # First retry: 2s
      expect(delays[1]).to be_within(0.5).of(4.0)  # Second retry: 4s
      expect(delays[2]).to be_within(0.5).of(8.0)  # Third retry: 8s
    end

    it 'uses initial_delay for first retry' do
      policy = described_class.new(
        max_attempts: 2,
        backoff_multiplier: 2,
        initial_delay: 5,
        logger: mock_logger,
        error_handling: { retryable: [StandardError],
                          non_retryable: [] }
      )

      execution_count = 0
      start_time = nil
      first_retry_time = nil

      policy.execute do
        if execution_count.zero?
          start_time = Time.zone.now
        else
          first_retry_time = Time.zone.now
        end

        execution_count += 1
        raise StandardError if execution_count < 2

        'success'
      end

      delay = first_retry_time - start_time
      expect(delay).to be_within(0.5).of(5.0)
    end
  end

  describe 'configuration validation' do
    it 'requires max_attempts > 0' do
      expect do
        described_class.new(
          max_attempts: 0,
          backoff_multiplier: 2,
          initial_delay: 1,
          logger: mock_logger,
          error_handling: { retryable: [],
                            non_retryable: [] }
        )
      end.to raise_error(ArgumentError, /max_attempts must be greater than 0/)
    end

    it 'requires backoff_multiplier > 0' do
      expect do
        described_class.new(
          max_attempts: 3,
          backoff_multiplier: 0,
          initial_delay: 1,
          logger: mock_logger,
          error_handling: { retryable: [],
                            non_retryable: [] }
        )
      end.to raise_error(ArgumentError, /backoff_multiplier must be greater than 0/)
    end

    it 'requires initial_delay >= 0' do
      expect do
        described_class.new(
          max_attempts: 3,
          backoff_multiplier: 2,
          initial_delay: -1,
          logger: mock_logger,
          error_handling: { retryable: [],
                            non_retryable: [] }
        )
      end.to raise_error(ArgumentError, /initial_delay must be greater than or equal to 0/)
    end
  end

  describe 'framework-agnostic usage' do
    it 'works without Rails' do
      hide_const('Rails') if defined?(Rails)

      policy = described_class.new(
        max_attempts: 2,
        backoff_multiplier: 2,
        initial_delay: 0.1,
        logger: Testing::Utils::NullLogger.new,
        error_handling: { retryable: [StandardError],
                          non_retryable: [] }
      )

      result = policy.execute { 'success' }
      expect(result).to eq('success')
    end

    it 'works with custom logger implementation' do
      custom_logger = Object.new
      def custom_logger.warn(msg); end
      def custom_logger.info(msg); end

      policy = described_class.new(
        max_attempts: 2,
        backoff_multiplier: 2,
        initial_delay: 0.1,
        logger: custom_logger,
        error_handling: { retryable: [StandardError],
                          non_retryable: [] }
      )

      result = policy.execute { 'success' }
      expect(result).to eq('success')
    end
  end

  describe 'edge cases' do
    it 'handles zero initial_delay' do
      policy = described_class.new(
        max_attempts: 2,
        backoff_multiplier: 2,
        initial_delay: 0,
        logger: mock_logger,
        error_handling: { retryable: [StandardError],
                          non_retryable: [] }
      )

      execution_count = 0

      result = policy.execute do
        execution_count += 1
        raise StandardError if execution_count < 2

        'success'
      end

      expect(result).to eq('success')
      expect(execution_count).to eq(2)
    end

    it 'handles max_attempts = 1 (no retry)' do
      policy = described_class.new(
        max_attempts: 1,
        backoff_multiplier: 2,
        initial_delay: 1,
        logger: mock_logger,
        error_handling: { retryable: [StandardError],
                          non_retryable: [] }
      )

      execution_count = 0

      expect do
        policy.execute do
          execution_count += 1
          raise StandardError, 'Error'
        end
      end.to raise_error(StandardError)

      expect(execution_count).to eq(1)
    end

    it 'handles empty retryable_errors list (retries all errors)' do
      policy = described_class.new(
        max_attempts: 3,
        backoff_multiplier: 2,
        initial_delay: 0.1,
        logger: mock_logger,
        error_handling: { retryable: [],
                          non_retryable: [] }
      )

      execution_count = 0

      result = policy.execute do
        execution_count += 1
        raise StandardError if execution_count < 2

        'success'
      end

      expect(result).to eq('success')
      expect(execution_count).to eq(2)
    end
  end

  describe 'concurrency safety' do
    it 'executes blocks in sequence for single thread' do
      execution_order = []

      retry_policy.execute do
        execution_order << 1
        'success'
      end

      retry_policy.execute do
        execution_order << 2
        'success'
      end

      expect(execution_order).to eq([1, 2])
    end
  end
end
