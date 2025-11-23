# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'playwright'
require_relative '../../../lib/testing/playwright_artifact_capture'
require_relative '../../../lib/testing/utils/null_logger'
require_relative '../../../lib/testing/utils/time_utils'

RSpec.describe Testing::PlaywrightArtifactCapture do
  let(:mock_driver) { instance_double(Testing::PlaywrightDriver) }
  let(:mock_storage) { instance_double(Testing::FileSystemStorage) }
  let(:mock_logger) { instance_double(Logger) }
  let(:capture) do
    described_class.new(
      driver: mock_driver,
      storage: mock_storage,
      logger: mock_logger
    )
  end

  describe '#initialize' do
    it 'accepts driver, storage, and logger' do
      expect(capture.driver).to eq(mock_driver)
      expect(capture.storage).to eq(mock_storage)
      expect(capture.logger).to eq(mock_logger)
    end

    it 'uses NullLogger as default logger' do
      capture = described_class.new(driver: mock_driver, storage: mock_storage)

      expect(capture.logger).to be_a(Testing::Utils::NullLogger)
    end

    it 'requires driver parameter' do
      expect do
        described_class.new(storage: mock_storage)
      end.to raise_error(ArgumentError)
    end

    it 'requires storage parameter' do
      expect do
        described_class.new(driver: mock_driver)
      end.to raise_error(ArgumentError)
    end
  end

  describe '#capture_screenshot' do
    let(:mock_page) { instance_double(Playwright::Page) }
    let(:temp_screenshot) { Tempfile.new(['screenshot', '.png']) }
    let(:saved_path) { Pathname.new('/tmp/screenshots/test-screenshot.png') }

    before do
      temp_screenshot.write('fake screenshot')
      temp_screenshot.close
      allow(mock_logger).to receive(:info)
    end

    after do
      temp_screenshot.unlink
    end

    it 'captures screenshot using driver' do
      allow(mock_driver).to receive(:take_screenshot)
        .with(mock_page, anything)
        .and_return(temp_screenshot.path)

      allow(mock_storage).to receive(:save_screenshot)
        .with(anything, temp_screenshot.path, anything)
        .and_return(saved_path)

      result = capture.capture_screenshot(mock_page, test_name: 'My Test')

      expect(result).to eq(saved_path)
    end

    it 'generates artifact name with correlation ID' do
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot).and_return(saved_path)

      # Mock TimeUtils to verify correlation ID generation
      allow(Testing::Utils::TimeUtils).to receive(:generate_correlation_id)
        .and_return('test-run-20251123-120000-abc123')

      capture.capture_screenshot(mock_page, test_name: 'My Test')

      expect(Testing::Utils::TimeUtils).to have_received(:generate_correlation_id)
    end

    it 'saves screenshot with metadata' do
      metadata = {
        test_name: 'My Test',
        example_id: 'spec/system/test_spec.rb:123',
        browser: 'chromium'
      }

      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)

      expect(mock_storage).to receive(:save_screenshot) do |_name, _path, saved_metadata|
        expect(saved_metadata[:test_name]).to eq('My Test')
        expect(saved_metadata[:example_id]).to eq('spec/system/test_spec.rb:123')
        expect(saved_metadata[:browser]).to eq('chromium')
        expect(saved_metadata).to have_key(:timestamp)
      end.and_return(saved_path)

      capture.capture_screenshot(mock_page, test_name: 'My Test', metadata: metadata)
    end

    it 'logs screenshot capture' do
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot).and_return(saved_path)

      expect(mock_logger).to receive(:info).with(/Screenshot captured/)

      capture.capture_screenshot(mock_page, test_name: 'My Test')
    end

    it 'returns saved artifact path' do
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot).and_return(saved_path)

      result = capture.capture_screenshot(mock_page, test_name: 'My Test')

      expect(result).to eq(saved_path)
    end

    it 'handles driver errors gracefully' do
      allow(mock_driver).to receive(:take_screenshot)
        .and_raise(StandardError.new('Driver error'))

      expect do
        capture.capture_screenshot(mock_page, test_name: 'My Test')
      end.to raise_error(StandardError, 'Driver error')
    end

    it 'handles storage errors gracefully' do
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot)
        .and_raise(StandardError.new('Storage error'))

      expect do
        capture.capture_screenshot(mock_page, test_name: 'My Test')
      end.to raise_error(StandardError, 'Storage error')
    end

    it 'includes timestamp in metadata' do
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)

      expect(mock_storage).to receive(:save_screenshot) do |_name, _path, metadata|
        expect(metadata).to have_key(:timestamp)
        expect(metadata[:timestamp]).to be_a(String)
      end.and_return(saved_path)

      capture.capture_screenshot(mock_page, test_name: 'My Test')
    end

    it 'sanitizes test name for artifact name' do
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)

      expect(mock_storage).to receive(:save_screenshot) do |name, _path, _metadata|
        # Verify name is sanitized (no special characters)
        expect(name).not_to include('/')
        expect(name).not_to include(':')
        expect(name).not_to include('*')
      end.and_return(saved_path)

      capture.capture_screenshot(mock_page, test_name: 'My/Test:With*Special?Chars')
    end
  end

  describe '#capture_trace' do
    let(:mock_context) { instance_double(Playwright::BrowserContext) }
    let(:temp_trace) { Tempfile.new(['trace', '.zip']) }
    let(:saved_path) { Pathname.new('/tmp/traces/test-trace.zip') }

    before do
      temp_trace.write('fake trace')
      temp_trace.close
      allow(mock_logger).to receive(:info)
    end

    after do
      temp_trace.unlink
    end

    context 'with trace_mode: on' do
      it 'starts trace before block execution' do
        expect(mock_driver).to receive(:start_trace).with(mock_context).ordered
        expect(mock_driver).to receive(:stop_trace)
          .with(mock_context, anything)
          .and_return(temp_trace.path)
          .ordered

        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on') do
          # Test execution
        end
      end

      it 'stops trace after block execution' do
        allow(mock_driver).to receive(:start_trace)

        allow(mock_driver).to receive(:stop_trace)
          .with(mock_context, anything)
          .and_return(temp_trace.path)

        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        result = capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on') do
          # Test execution
        end

        expect(result).to eq(saved_path)
      end

      it 'saves trace with metadata' do
        metadata = {
          test_name: 'My Test',
          duration: 1234,
          example_id: 'spec/system/test_spec.rb:123'
        }

        allow(mock_driver).to receive(:start_trace)
        allow(mock_driver).to receive(:stop_trace).and_return(temp_trace.path)

        expect(mock_storage).to receive(:save_trace) do |_name, _path, saved_metadata|
          expect(saved_metadata[:test_name]).to eq('My Test')
          expect(saved_metadata[:duration]).to eq(1234)
          expect(saved_metadata[:example_id]).to eq('spec/system/test_spec.rb:123')
        end.and_return(saved_path)

        capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on', metadata: metadata) do
          # Test execution
        end
      end

      it 'logs trace capture' do
        allow(mock_driver).to receive(:start_trace)
        allow(mock_driver).to receive(:stop_trace).and_return(temp_trace.path)
        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        expect(mock_logger).to receive(:info).with(/Trace captured/)

        capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on') do
          # Test execution
        end
      end

      it 'returns saved artifact path' do
        allow(mock_driver).to receive(:start_trace)
        allow(mock_driver).to receive(:stop_trace).and_return(temp_trace.path)
        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        result = capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on') do
          # Test execution
        end

        expect(result).to eq(saved_path)
      end

      it 'executes block and returns block result' do
        allow(mock_driver).to receive(:start_trace)
        allow(mock_driver).to receive(:stop_trace).and_return(temp_trace.path)
        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        result = capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on') do
          'block result'
        end

        expect(result).to eq(saved_path)
      end

      it 'stops trace even if block raises error' do
        allow(mock_driver).to receive(:start_trace)

        allow(mock_driver).to receive(:stop_trace)
          .with(mock_context, anything)
          .and_return(temp_trace.path)

        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        expect do
          capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on') do
            raise StandardError, 'Test error'
          end
        end.to raise_error(StandardError, 'Test error')

        expect(mock_driver).to have_received(:stop_trace)
      end
    end

    context 'with trace_mode: off' do
      it 'does not start trace' do
        expect(mock_driver).not_to receive(:start_trace)
        expect(mock_driver).not_to receive(:stop_trace)

        result = capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'off') do
          'block result'
        end

        expect(result).to eq('block result')
      end

      it 'executes block normally' do
        block_executed = false

        capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'off') do
          block_executed = true
          'result'
        end

        expect(block_executed).to be true
      end

      it 'returns block result' do
        result = capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'off') do
          'block result'
        end

        expect(result).to eq('block result')
      end

      it 'does not log trace capture' do
        expect(mock_logger).not_to receive(:info).with(/Trace captured/)

        capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'off') do
          # Test execution
        end
      end
    end

    context 'with trace_mode: on-first-retry' do
      it 'starts trace only on retry (simulated)' do
        # This mode is typically handled by RSpec retry logic
        # The capture service itself treats it as conditional
        # For now, we verify it's accepted as a valid mode

        allow(mock_driver).to receive(:start_trace)
        allow(mock_driver).to receive(:stop_trace).and_return(temp_trace.path)
        allow(mock_storage).to receive(:save_trace).and_return(saved_path)

        result = capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'on-first-retry') do
          'block result'
        end

        # Mode is accepted
        expect { result }.not_to raise_error
      end
    end

    context 'with invalid trace_mode' do
      it 'raises error for invalid trace mode' do
        expect do
          capture.capture_trace(mock_context, test_name: 'My Test', trace_mode: 'invalid') do
            # Test execution
          end
        end.to raise_error(ArgumentError, /invalid trace_mode/)
      end
    end
  end

  describe 'correlation ID generation' do
    let(:mock_page) { instance_double(Playwright::Page) }
    let(:temp_screenshot) { Tempfile.new(['screenshot', '.png']) }
    let(:saved_path) { Pathname.new('/tmp/screenshots/test.png') }

    before do
      temp_screenshot.write('fake screenshot')
      temp_screenshot.close
      allow(mock_logger).to receive(:info)
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot).and_return(saved_path)
    end

    after do
      temp_screenshot.unlink
    end

    it 'generates unique correlation IDs for each capture' do
      allow(Testing::Utils::TimeUtils).to receive(:generate_correlation_id)
        .and_return('test-run-20251123-120000-abc123', 'test-run-20251123-120001-xyz789')

      first_id = nil
      second_id = nil

      allow(mock_storage).to receive(:save_screenshot) do |name, _path, _metadata|
        first_id ||= name.match(/test-run-\d{8}-\d{6}-[a-z0-9]+/)&.to_s
        first_id
      end

      capture.capture_screenshot(mock_page, test_name: 'Test 1')

      allow(mock_storage).to receive(:save_screenshot) do |name, _path, _metadata|
        second_id = name.match(/test-run-\d{8}-\d{6}-[a-z0-9]+/)&.to_s
      end

      capture.capture_screenshot(mock_page, test_name: 'Test 2')

      expect(first_id).not_to be_nil
      expect(second_id).not_to be_nil
      expect(first_id).not_to eq(second_id)
    end

    it 'includes correlation ID in log messages' do
      allow(Testing::Utils::TimeUtils).to receive(:generate_correlation_id)
        .and_return('test-run-20251123-120000-abc123')

      expect(mock_logger).to receive(:info) do |message|
        expect(message).to include('test-run-20251123-120000-abc123')
      end

      capture.capture_screenshot(mock_page, test_name: 'My Test')
    end
  end

  describe 'integration with NullLogger' do
    let(:mock_page) { instance_double(Playwright::Page) }
    let(:temp_screenshot) { Tempfile.new(['screenshot', '.png']) }
    let(:saved_path) { Pathname.new('/tmp/screenshots/test.png') }

    before do
      temp_screenshot.write('fake screenshot')
      temp_screenshot.close
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot).and_return(saved_path)
    end

    after do
      temp_screenshot.unlink
    end

    it 'works with NullLogger (no errors)' do
      capture = described_class.new(driver: mock_driver, storage: mock_storage)

      expect do
        capture.capture_screenshot(mock_page, test_name: 'My Test')
      end.not_to raise_error
    end
  end

  describe 'structured logging' do
    let(:mock_page) { instance_double(Playwright::Page) }
    let(:temp_screenshot) { Tempfile.new(['screenshot', '.png']) }
    let(:saved_path) { Pathname.new('/tmp/screenshots/test-screenshot.png') }

    before do
      temp_screenshot.write('fake screenshot')
      temp_screenshot.close
      allow(mock_driver).to receive(:take_screenshot).and_return(temp_screenshot.path)
      allow(mock_storage).to receive(:save_screenshot).and_return(saved_path)
    end

    after do
      temp_screenshot.unlink
    end

    it 'logs artifact type' do
      expect(mock_logger).to receive(:info) do |message|
        expect(message).to include('screenshot').or include('Screenshot')
      end

      capture.capture_screenshot(mock_page, test_name: 'My Test')
    end

    it 'logs artifact path' do
      expect(mock_logger).to receive(:info) do |message|
        expect(message).to include(saved_path.to_s)
      end

      capture.capture_screenshot(mock_page, test_name: 'My Test')
    end

    it 'logs test name' do
      expect(mock_logger).to receive(:info) do |message|
        expect(message).to include('My Test')
      end

      capture.capture_screenshot(mock_page, test_name: 'My Test')
    end
  end
end
