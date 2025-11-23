# frozen_string_literal: true

require 'spec_helper'
require 'playwright'
require_relative '../../../lib/testing/playwright_browser_session'

RSpec.describe Testing::PlaywrightBrowserSession do
  let(:mock_driver) { instance_double(Testing::PlaywrightDriver) }
  let(:session) do
    described_class.new(
      driver: mock_driver,
      config: mock_config,
      artifact_capture: mock_artifact_capture,
      retry_policy: mock_retry_policy
    )
  end
  let(:mock_config) { instance_double(Testing::PlaywrightConfiguration) }
  let(:mock_artifact_capture) { instance_double(Testing::PlaywrightArtifactCapture) }
  let(:mock_retry_policy) { instance_double(Testing::RetryPolicy) }
  let(:mock_browser) { instance_double(Playwright::Browser) }
  let(:mock_context) { instance_double(Playwright::BrowserContext, close: nil) }

  before do
    allow(mock_config).to receive_messages(browser_type: 'chromium', headless: true)
  end

  describe '#initialize' do
    it 'accepts driver, config, artifact_capture, and retry_policy' do
      expect(session.driver).to eq(mock_driver)
      expect(session.config).to eq(mock_config)
      expect(session.artifact_capture).to eq(mock_artifact_capture)
      expect(session.retry_policy).to eq(mock_retry_policy)
    end

    it 'initializes with nil browser and context' do
      expect(session.browser).to be_nil
      expect(session.context).to be_nil
    end

    it 'requires driver parameter' do
      expect do
        described_class.new(
          config: mock_config,
          artifact_capture: mock_artifact_capture,
          retry_policy: mock_retry_policy
        )
      end.to raise_error(ArgumentError)
    end

    it 'requires config parameter' do
      expect do
        described_class.new(
          driver: mock_driver,
          artifact_capture: mock_artifact_capture,
          retry_policy: mock_retry_policy
        )
      end.to raise_error(ArgumentError)
    end

    it 'requires artifact_capture parameter' do
      expect do
        described_class.new(
          driver: mock_driver,
          config: mock_config,
          retry_policy: mock_retry_policy
        )
      end.to raise_error(ArgumentError)
    end

    it 'requires retry_policy parameter' do
      expect do
        described_class.new(
          driver: mock_driver,
          config: mock_config,
          artifact_capture: mock_artifact_capture
        )
      end.to raise_error(ArgumentError)
    end
  end

  describe '#start' do
    before do
      allow(mock_driver).to receive(:launch_browser).with(mock_config).and_return(mock_browser)
      allow(mock_driver).to receive(:create_context).with(mock_browser, mock_config).and_return(mock_context)
    end

    it 'launches browser and creates context' do
      session.start

      expect(session.browser).to eq(mock_browser)
      expect(session.context).to eq(mock_context)
    end

    it 'raises error if browser launch fails' do
      allow(mock_driver).to receive(:launch_browser).and_raise(StandardError.new('Launch failed'))

      expect do
        session.start
      end.to raise_error(StandardError, 'Launch failed')
    end

    it 'only launches browser once (idempotent)' do
      expect(mock_driver).to receive(:launch_browser).once.and_return(mock_browser)

      session.start
      session.start # Second call should not launch again

      expect(session.browser).to eq(mock_browser)
    end
  end

  describe '#stop' do
    before do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      allow(mock_driver).to receive(:close_browser)
      allow(mock_context).to receive(:close)
      session.start
    end

    it 'closes browser using driver' do
      expect(mock_driver).to receive(:close_browser).with(mock_browser)

      session.stop
    end

    it 'sets browser to nil after closing' do
      allow(mock_driver).to receive(:close_browser)

      session.stop

      expect(session.browser).to be_nil
    end

    it 'closes context before closing browser' do
      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      allow(mock_context).to receive(:close)

      session.create_context

      expect(mock_context).to receive(:close).ordered
      expect(mock_driver).to receive(:close_browser).ordered

      session.stop
    end

    it 'handles browser already closed' do
      allow(mock_driver).to receive(:close_browser)

      session.stop

      expect { session.stop }.not_to raise_error # Second call should not raise error
    end

    it 'sets context to nil after closing' do
      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      allow(mock_context).to receive(:close)
      allow(mock_driver).to receive(:close_browser)

      session.create_context
      session.stop

      expect(session.context).to be_nil
    end
  end

  describe '#restart' do
    before do
      allow(mock_driver).to receive(:launch_browser).and_return(mock_browser)
      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      allow(mock_driver).to receive(:close_browser)
    end

    it 'stops and then starts the browser' do
      session.start

      expect(session).to receive(:stop).ordered
      expect(session).to receive(:start).ordered

      session.restart
    end

    it 'returns the new browser instance' do
      session.start

      result = session.restart

      expect(result).to eq(mock_browser)
    end
  end

  describe '#create_context' do
    before do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      session.start
    end

    it 'creates context using driver' do
      session.create_context

      expect(session.context).to eq(mock_context)
    end

    it 'returns the context instance' do
      result = session.create_context

      expect(result).to eq(mock_context)
    end

    it 'ensures browser is started before creating context' do
      session2 = described_class.new(
        driver: mock_driver,
        config: mock_config,
        artifact_capture: mock_artifact_capture,
        retry_policy: mock_retry_policy
      )

      allow(mock_driver).to receive_messages(
        launch_browser: mock_browser,
        create_context: mock_context
      )

      result = session2.create_context

      expect(result).to eq(mock_context)
      expect(session2.browser).to eq(mock_browser)
    end

    it 'closes existing context before creating new one' do
      allow(mock_driver).to receive(:create_context).and_return(mock_context)

      session.create_context

      old_context = session.context
      expect(old_context).to receive(:close)

      new_context = instance_double(Playwright::BrowserContext)
      allow(mock_driver).to receive(:create_context).and_return(new_context)

      session.create_context

      expect(session.context).to eq(new_context)
    end
  end

  describe '#close_context' do
    before do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      allow(mock_context).to receive(:close)
      session.start
      session.create_context
    end

    it 'closes the context' do
      expect(mock_context).to receive(:close)

      session.close_context
    end

    it 'sets context to nil after closing' do
      session.close_context

      expect(session.context).to be_nil
    end

    it 'handles context already closed' do
      session.close_context

      expect { session.close_context }.not_to raise_error # Second call should not raise error
    end

    it 'does not close browser' do
      expect(mock_driver).not_to receive(:close_browser)

      session.close_context

      expect(session.browser).to eq(mock_browser)
    end
  end

  describe '#execute_with_retry' do
    before do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      session.start
      session.create_context
    end

    it 'executes block with retry policy' do
      expect(mock_retry_policy).to receive(:execute).and_yield

      result = session.execute_with_retry(test_name: 'My Test') do
        'success'
      end

      expect(result).to eq('success')
    end

    it 'passes block to retry policy' do
      block_executed = false

      allow(mock_retry_policy).to receive(:execute).and_yield

      session.execute_with_retry(test_name: 'My Test') do
        block_executed = true
        'result'
      end

      expect(block_executed).to be true
    end

    it 'returns block result' do
      allow(mock_retry_policy).to receive(:execute).and_yield

      result = session.execute_with_retry(test_name: 'My Test') do
        'block result'
      end

      expect(result).to eq('block result')
    end

    it 'captures screenshot on failure' do
      mock_page = instance_double(Playwright::Page)
      allow(mock_context).to receive(:pages).and_return([mock_page])

      allow(mock_retry_policy).to receive(:execute).and_yield

      expect(mock_artifact_capture).to receive(:capture_screenshot)
        .with(mock_page, hash_including(test_name: 'My Test'))

      expect do
        session.execute_with_retry(test_name: 'My Test') do
          raise StandardError, 'Test error'
        end
      end.to raise_error(StandardError)
    end

    it 'passes test_name to artifact capture' do
      allow(mock_retry_policy).to receive(:execute).and_yield

      mock_page = instance_double(Playwright::Page)
      allow(mock_context).to receive(:pages).and_return([mock_page])

      expect(mock_artifact_capture).to receive(:capture_screenshot) do |_page, options|
        expect(options[:test_name]).to eq('My Test')
      end

      expect do
        session.execute_with_retry(test_name: 'My Test') do
          raise StandardError
        end
      end.to raise_error(StandardError)
    end

    it 'includes metadata in artifact capture' do
      metadata = { example_id: 'spec/system/test_spec.rb:123', browser: 'chromium' }

      allow(mock_retry_policy).to receive(:execute).and_yield

      mock_page = instance_double(Playwright::Page)
      allow(mock_context).to receive(:pages).and_return([mock_page])

      expect(mock_artifact_capture).to receive(:capture_screenshot) do |_page, options|
        expect(options[:metadata][:example_id]).to eq('spec/system/test_spec.rb:123')
        expect(options[:metadata][:browser]).to eq('chromium')
      end

      expect do
        session.execute_with_retry(test_name: 'My Test', metadata: metadata) do
          raise StandardError
        end
      end.to raise_error(StandardError)
    end

    it 'ensures context is created before execution' do
      session2 = described_class.new(
        driver: mock_driver,
        config: mock_config,
        artifact_capture: mock_artifact_capture,
        retry_policy: mock_retry_policy
      )

      allow(mock_driver).to receive_messages(
        launch_browser: mock_browser,
        create_context: mock_context
      )

      allow(mock_retry_policy).to receive(:execute).and_yield

      result = session2.execute_with_retry(test_name: 'My Test') do
        'success'
      end

      expect(result).to eq('success')
    end

    it 'handles multiple page scenario (captures first page)' do
      mock_page1 = instance_double(Playwright::Page)
      mock_page2 = instance_double(Playwright::Page)
      allow(mock_context).to receive(:pages).and_return([mock_page1, mock_page2])

      allow(mock_retry_policy).to receive(:execute).and_yield

      expect(mock_artifact_capture).to receive(:capture_screenshot)
        .with(mock_page1, anything)

      expect do
        session.execute_with_retry(test_name: 'My Test') do
          raise StandardError
        end
      end.to raise_error(StandardError)
    end

    it 'handles no pages scenario gracefully' do
      allow(mock_context).to receive(:pages).and_return([])

      allow(mock_retry_policy).to receive(:execute).and_yield

      expect(mock_artifact_capture).not_to receive(:capture_screenshot)

      expect do
        session.execute_with_retry(test_name: 'My Test') do
          raise StandardError, 'Error'
        end
      end.to raise_error(StandardError)
    end
  end

  describe 'resource cleanup' do
    before do
      allow(mock_driver).to receive(:close_browser)
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      allow(mock_context).to receive(:close)
    end

    it 'closes context and browser when stop is called' do
      session.start
      session.create_context

      expect(mock_context).to receive(:close).ordered
      expect(mock_driver).to receive(:close_browser).ordered

      session.stop
    end

    it 'cleans up even if close raises error' do
      session.start
      session.create_context

      allow(mock_context).to receive(:close).and_raise(StandardError.new('Close failed'))

      session.stop

      # Both cleanup attempts should have been made despite error
      expect(mock_context).to have_received(:close)
      expect(mock_driver).to have_received(:close_browser)
      # Context and browser should be nil after cleanup
      expect(session.context).to be_nil
      expect(session.browser).to be_nil
    end
  end

  describe 'browser lifecycle' do
    before do
      allow(mock_driver).to receive(:launch_browser).and_return(mock_browser)
      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      allow(mock_driver).to receive(:close_browser)
    end

    it 'follows start -> create_context -> close_context -> stop lifecycle' do
      session.start
      expect(session.browser).to eq(mock_browser)
      expect(session.context).to eq(mock_context)

      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      session.create_context
      expect(session.context).to eq(mock_context)

      allow(mock_context).to receive(:close)
      session.close_context
      expect(session.context).to be_nil
      expect(session.browser).to eq(mock_browser)

      session.stop
      expect(session.browser).to be_nil
    end
  end

  describe 'integration with components' do
    it 'uses driver for browser operations' do
      allow(mock_driver).to receive(:launch_browser).with(mock_config).and_return(mock_browser)
      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      allow(mock_driver).to receive(:close_browser).with(mock_browser)

      session.start
      session.stop

      expect(session.browser).to be_nil
    end

    it 'uses config for browser configuration' do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)

      session.start
      result = session.create_context

      expect(result).to eq(mock_context)
    end

    it 'uses artifact_capture for screenshot capture' do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      allow(mock_retry_policy).to receive(:execute).and_yield

      mock_page = instance_double(Playwright::Page)
      allow(mock_context).to receive(:pages).and_return([mock_page])

      session.start
      session.create_context

      expect(mock_artifact_capture).to receive(:capture_screenshot)
        .with(mock_page, anything)

      expect do
        session.execute_with_retry(test_name: 'My Test') do
          raise StandardError
        end
      end.to raise_error(StandardError)
    end

    it 'uses retry_policy for retry logic' do
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)

      session.start
      session.create_context

      expect(mock_retry_policy).to receive(:execute).and_yield

      session.execute_with_retry(test_name: 'My Test') do
        'success'
      end
    end
  end

  describe 'framework-agnostic usage' do
    it 'works without Rails' do
      hide_const('Rails') if defined?(Rails)

      allow(mock_driver).to receive(:launch_browser).and_return(mock_browser)
      allow(mock_driver).to receive(:create_context).and_return(mock_context)
      allow(mock_driver).to receive(:close_browser)

      session.start
      expect(session.browser).to eq(mock_browser)

      session.stop
      expect(session.browser).to be_nil
    end

    it 'works with Minitest (simulated)' do
      # Simulates Minitest setup/teardown
      allow(mock_driver).to receive_messages(launch_browser: mock_browser, create_context: mock_context)
      allow(mock_driver).to receive(:close_browser)
      allow(mock_context).to receive(:close)
      allow(mock_retry_policy).to receive(:execute).and_yield

      # Setup
      session.start
      session.create_context

      # Test execution
      result = session.execute_with_retry(test_name: 'test_homepage') do
        'test passed'
      end
      expect(result).to eq('test passed')

      # Teardown
      session.stop
    end
  end

  describe 'error scenarios' do
    it 'raises error if driver is nil' do
      expect do
        described_class.new(
          driver: nil,
          config: mock_config,
          artifact_capture: mock_artifact_capture,
          retry_policy: mock_retry_policy
        )
      end.to raise_error(ArgumentError)
    end

    it 'raises error if config is nil' do
      expect do
        described_class.new(
          driver: mock_driver,
          config: nil,
          artifact_capture: mock_artifact_capture,
          retry_policy: mock_retry_policy
        )
      end.to raise_error(ArgumentError)
    end

    it 'handles browser launch timeout' do
      allow(mock_driver).to receive(:launch_browser).and_raise(Timeout::Error.new('Browser launch timeout'))

      expect do
        session.start
      end.to raise_error(Timeout::Error)
    end

    it 'handles context creation failure' do
      allow(mock_driver).to receive(:launch_browser).and_return(mock_browser)
      allow(mock_driver).to receive(:create_context).and_raise(StandardError.new('Context creation failed'))

      session.start

      expect do
        session.create_context
      end.to raise_error(StandardError, 'Context creation failed')
    end
  end
end
