# frozen_string_literal: true

require 'spec_helper'
require 'pathname'

# Mock Playwright module before loading the driver
module Playwright
  def self.create(_options = {})
    # Will be stubbed in tests
  end
end

require_relative '../../../lib/testing/browser_driver'
require_relative '../../../lib/testing/playwright_driver'

RSpec.describe Testing::PlaywrightDriver do
  # Mock the Playwright module and its classes
  let(:mock_playwright) { double('Playwright') }
  let(:mock_browser_type) { double('BrowserType') }
  let(:mock_browser) { double('Browser') }
  let(:mock_context) { double('BrowserContext') }
  let(:mock_tracing) { double('Tracing') }
  let(:mock_page) { double('Page') }

  let(:mock_config) do
    double(
      'PlaywrightConfiguration',
      browser_type: 'chromium',
      browser_launch_options: { headless: true, timeout: 30_000, slowMo: 0 },
      browser_context_options: {
        viewport: { width: 1920, height: 1080 },
        recordVideo: { dir: '/tmp/screenshots' }
      }
    )
  end

  before do
    # Stub Playwright.create for each test
    allow(Playwright).to receive(:create).and_return(mock_playwright)
  end

  describe '#initialize' do
    it 'creates Playwright instance with npx playwright executable' do
      expect(Playwright).to receive(:create).with(
        playwright_cli_executable_path: 'npx playwright'
      ).and_return(mock_playwright)

      driver = described_class.new

      expect(driver.playwright).to eq(mock_playwright)
    end

    # NOTE: Testing the LoadError scenario requires stubbing Kernel#require
    # which can cause issues in test environment. In practice, the error
    # message is comprehensive and includes installation instructions.
  end

  describe '#launch_browser' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'launches browser with configuration options' do
      allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
      allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

      browser = driver.launch_browser(mock_config)

      expect(mock_playwright).to have_received(:chromium)
      expect(mock_browser_type).to have_received(:launch).with(
        headless: true,
        timeout: 30_000,
        slowMo: 0
      )
      expect(browser).to eq(mock_browser)
    end

    context 'with different browser types' do
      it 'launches chromium browser' do
        allow(mock_config).to receive(:browser_type).and_return('chromium')
        allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_playwright).to have_received(:chromium)
      end

      it 'launches firefox browser' do
        allow(mock_config).to receive(:browser_type).and_return('firefox')
        allow(mock_playwright).to receive(:firefox).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_playwright).to have_received(:firefox)
      end

      it 'launches webkit browser' do
        allow(mock_config).to receive(:browser_type).and_return('webkit')
        allow(mock_playwright).to receive(:webkit).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_playwright).to have_received(:webkit)
      end
    end

    context 'with different configurations' do
      it 'launches in headless mode' do
        allow(mock_config).to receive(:browser_launch_options)
          .and_return(headless: true, timeout: 30_000, slowMo: 0)
        allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_browser_type).to have_received(:launch).with(
          hash_including(headless: true)
        )
      end

      it 'launches in headed mode' do
        allow(mock_config).to receive(:browser_launch_options)
          .and_return(headless: false, timeout: 30_000, slowMo: 0)
        allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_browser_type).to have_received(:launch).with(
          hash_including(headless: false)
        )
      end

      it 'launches with custom timeout' do
        allow(mock_config).to receive(:browser_launch_options)
          .and_return(headless: true, timeout: 60_000, slowMo: 0)
        allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_browser_type).to have_received(:launch).with(
          hash_including(timeout: 60_000)
        )
      end

      it 'launches with slow motion' do
        allow(mock_config).to receive(:browser_launch_options)
          .and_return(headless: true, timeout: 30_000, slowMo: 500)
        allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
        allow(mock_browser_type).to receive(:launch).and_return(mock_browser)

        driver.launch_browser(mock_config)

        expect(mock_browser_type).to have_received(:launch).with(
          hash_including(slowMo: 500)
        )
      end
    end
  end

  describe '#close_browser' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'closes the browser' do
      allow(mock_browser).to receive(:close)

      driver.close_browser(mock_browser)

      expect(mock_browser).to have_received(:close)
    end

    it 'handles nil browser gracefully' do
      expect { driver.close_browser(nil) }.not_to raise_error
    end
  end

  describe '#create_context' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'creates browser context with configuration options' do
      allow(mock_browser).to receive(:new_context).and_return(mock_context)

      context = driver.create_context(mock_browser, mock_config)

      expect(mock_browser).to have_received(:new_context).with(
        viewport: { width: 1920, height: 1080 },
        recordVideo: { dir: '/tmp/screenshots' }
      )
      expect(context).to eq(mock_context)
    end

    it 'creates context with custom viewport' do
      allow(mock_config).to receive(:browser_context_options).and_return(
        viewport: { width: 1280, height: 720 },
        recordVideo: { dir: '/tmp/screenshots' }
      )
      allow(mock_browser).to receive(:new_context).and_return(mock_context)

      driver.create_context(mock_browser, mock_config)

      expect(mock_browser).to have_received(:new_context).with(
        hash_including(viewport: { width: 1280, height: 720 })
      )
    end

    it 'creates context with video recording enabled' do
      allow(mock_browser).to receive(:new_context).and_return(mock_context)

      driver.create_context(mock_browser, mock_config)

      expect(mock_browser).to have_received(:new_context).with(
        hash_including(recordVideo: { dir: '/tmp/screenshots' })
      )
    end
  end

  describe '#take_screenshot' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    let(:screenshot_path) { '/tmp/screenshots/test.png' }
    let(:pathname_path) { Pathname.new(screenshot_path) }

    it 'takes full page screenshot' do
      allow(mock_page).to receive(:screenshot)

      driver.take_screenshot(mock_page, screenshot_path)

      expect(mock_page).to have_received(:screenshot).with(
        path: screenshot_path,
        fullPage: true
      )
    end

    it 'accepts Pathname as path' do
      allow(mock_page).to receive(:screenshot)

      driver.take_screenshot(mock_page, pathname_path)

      expect(mock_page).to have_received(:screenshot).with(
        path: screenshot_path,
        fullPage: true
      )
    end

    it 'captures full page including scrollable content' do
      allow(mock_page).to receive(:screenshot)

      driver.take_screenshot(mock_page, screenshot_path)

      expect(mock_page).to have_received(:screenshot).with(
        hash_including(fullPage: true)
      )
    end
  end

  describe '#start_trace' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'starts tracing with screenshots, snapshots, and sources' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:start)

      driver.start_trace(mock_context)

      expect(mock_context).to have_received(:tracing)
      expect(mock_tracing).to have_received(:start).with(
        screenshots: true,
        snapshots: true,
        sources: true
      )
    end

    it 'enables screenshot capture' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:start)

      driver.start_trace(mock_context)

      expect(mock_tracing).to have_received(:start).with(
        hash_including(screenshots: true)
      )
    end

    it 'enables snapshot capture' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:start)

      driver.start_trace(mock_context)

      expect(mock_tracing).to have_received(:start).with(
        hash_including(snapshots: true)
      )
    end

    it 'enables source capture' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:start)

      driver.start_trace(mock_context)

      expect(mock_tracing).to have_received(:start).with(
        hash_including(sources: true)
      )
    end
  end

  describe '#stop_trace' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    let(:trace_path) { '/tmp/traces/test.zip' }
    let(:pathname_path) { Pathname.new(trace_path) }

    it 'stops tracing and saves to path' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:stop)

      driver.stop_trace(mock_context, trace_path)

      expect(mock_context).to have_received(:tracing)
      expect(mock_tracing).to have_received(:stop).with(path: trace_path)
    end

    it 'accepts Pathname as path' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:stop)

      driver.stop_trace(mock_context, pathname_path)

      expect(mock_tracing).to have_received(:stop).with(path: trace_path)
    end
  end

  describe 'integration with BrowserDriver interface' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'is a subclass of BrowserDriver' do
      expect(described_class).to be < Testing::BrowserDriver
    end

    it 'implements all required methods' do
      expect(driver).to respond_to(:launch_browser)
      expect(driver).to respond_to(:close_browser)
      expect(driver).to respond_to(:create_context)
      expect(driver).to respond_to(:take_screenshot)
      expect(driver).to respond_to(:start_trace)
      expect(driver).to respond_to(:stop_trace)
    end
  end

  describe 'error handling' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'propagates browser launch errors' do
      allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
      allow(mock_browser_type).to receive(:launch).and_raise(StandardError.new('Launch failed'))

      expect do
        driver.launch_browser(mock_config)
      end.to raise_error(StandardError, 'Launch failed')
    end

    it 'propagates screenshot errors' do
      allow(mock_page).to receive(:screenshot).and_raise(StandardError.new('Screenshot failed'))

      expect do
        driver.take_screenshot(mock_page, '/tmp/test.png')
      end.to raise_error(StandardError, 'Screenshot failed')
    end

    it 'propagates trace start errors' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:start).and_raise(StandardError.new('Trace start failed'))

      expect do
        driver.start_trace(mock_context)
      end.to raise_error(StandardError, 'Trace start failed')
    end

    it 'propagates trace stop errors' do
      allow(mock_context).to receive(:tracing).and_return(mock_tracing)
      allow(mock_tracing).to receive(:stop).and_raise(StandardError.new('Trace stop failed'))

      expect do
        driver.stop_trace(mock_context, '/tmp/trace.zip')
      end.to raise_error(StandardError, 'Trace stop failed')
    end
  end

  describe 'full workflow' do
    let(:driver) do
      allow(Playwright).to receive(:create).and_return(mock_playwright)
      described_class.new
    end

    it 'supports complete browser automation workflow' do
      # Setup mocks for full workflow
      allow(mock_playwright).to receive(:chromium).and_return(mock_browser_type)
      allow(mock_browser_type).to receive(:launch).and_return(mock_browser)
      allow(mock_browser).to receive(:new_context).and_return(mock_context)
      allow(mock_tracing).to receive(:start)
      allow(mock_tracing).to receive(:stop)
      allow(mock_context).to receive_messages(tracing: mock_tracing, new_page: mock_page)
      allow(mock_page).to receive(:goto)
      allow(mock_page).to receive(:screenshot)
      allow(mock_browser).to receive(:close)

      # Execute full workflow
      browser = driver.launch_browser(mock_config)
      context = driver.create_context(browser, mock_config)
      driver.start_trace(context)

      page = context.new_page
      page.goto('https://example.com')
      driver.take_screenshot(page, '/tmp/screenshot.png')

      driver.stop_trace(context, '/tmp/trace.zip')
      driver.close_browser(browser)

      # Verify all steps executed correctly
      expect(mock_playwright).to have_received(:chromium)
      expect(mock_browser_type).to have_received(:launch)
      expect(mock_browser).to have_received(:new_context)
      expect(mock_tracing).to have_received(:start)
      expect(mock_page).to have_received(:screenshot)
      expect(mock_tracing).to have_received(:stop)
      expect(mock_browser).to have_received(:close)
    end
  end
end
