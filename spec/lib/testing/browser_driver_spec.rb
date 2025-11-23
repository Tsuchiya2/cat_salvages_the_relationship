# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/testing/browser_driver'

RSpec.describe Testing::BrowserDriver do
  let(:driver) { described_class.new }
  let(:mock_config) { instance_double('Testing::PlaywrightConfiguration') }
  let(:mock_browser) { double('Browser') }
  let(:mock_context) { double('BrowserContext') }
  let(:mock_page) { double('Page') }
  let(:screenshot_path) { '/tmp/screenshots/test.png' }
  let(:trace_path) { '/tmp/traces/test.zip' }

  describe '#launch_browser' do
    it 'raises NotImplementedError' do
      expect do
        driver.launch_browser(mock_config)
      end.to raise_error(
        NotImplementedError,
        'Testing::BrowserDriver#launch_browser must be implemented'
      )
    end

    it 'includes class name in error message' do
      expect do
        driver.launch_browser(mock_config)
      end.to raise_error(NotImplementedError, /Testing::BrowserDriver/)
    end
  end

  describe '#close_browser' do
    it 'raises NotImplementedError' do
      expect do
        driver.close_browser(mock_browser)
      end.to raise_error(
        NotImplementedError,
        'Testing::BrowserDriver#close_browser must be implemented'
      )
    end

    it 'includes class name in error message' do
      expect do
        driver.close_browser(mock_browser)
      end.to raise_error(NotImplementedError, /Testing::BrowserDriver/)
    end
  end

  describe '#create_context' do
    it 'raises NotImplementedError' do
      expect do
        driver.create_context(mock_browser, mock_config)
      end.to raise_error(
        NotImplementedError,
        'Testing::BrowserDriver#create_context must be implemented'
      )
    end

    it 'includes class name in error message' do
      expect do
        driver.create_context(mock_browser, mock_config)
      end.to raise_error(NotImplementedError, /Testing::BrowserDriver/)
    end
  end

  describe '#take_screenshot' do
    it 'raises NotImplementedError' do
      expect do
        driver.take_screenshot(mock_page, screenshot_path)
      end.to raise_error(
        NotImplementedError,
        'Testing::BrowserDriver#take_screenshot must be implemented'
      )
    end

    it 'includes class name in error message' do
      expect do
        driver.take_screenshot(mock_page, screenshot_path)
      end.to raise_error(NotImplementedError, /Testing::BrowserDriver/)
    end
  end

  describe '#start_trace' do
    it 'raises NotImplementedError' do
      expect do
        driver.start_trace(mock_context)
      end.to raise_error(
        NotImplementedError,
        'Testing::BrowserDriver#start_trace must be implemented'
      )
    end

    it 'includes class name in error message' do
      expect do
        driver.start_trace(mock_context)
      end.to raise_error(NotImplementedError, /Testing::BrowserDriver/)
    end
  end

  describe '#stop_trace' do
    it 'raises NotImplementedError' do
      expect do
        driver.stop_trace(mock_context, trace_path)
      end.to raise_error(
        NotImplementedError,
        'Testing::BrowserDriver#stop_trace must be implemented'
      )
    end

    it 'includes class name in error message' do
      expect do
        driver.stop_trace(mock_context, trace_path)
      end.to raise_error(NotImplementedError, /Testing::BrowserDriver/)
    end
  end

  describe 'subclass implementation' do
    let(:custom_driver_class) do
      Class.new(Testing::BrowserDriver) do
        def launch_browser(_config)
          'custom browser'
        end

        def close_browser(_browser)
          'closed'
        end

        def create_context(_browser, _config)
          'custom context'
        end

        def take_screenshot(_page, _path)
          'screenshot taken'
        end

        def start_trace(_context)
          'trace started'
        end

        def stop_trace(_context, _path)
          'trace stopped'
        end
      end
    end

    let(:custom_driver) { custom_driver_class.new }

    it 'allows launch_browser to be overridden' do
      expect(custom_driver.launch_browser(mock_config)).to eq('custom browser')
    end

    it 'allows close_browser to be overridden' do
      expect(custom_driver.close_browser(mock_browser)).to eq('closed')
    end

    it 'allows create_context to be overridden' do
      expect(custom_driver.create_context(mock_browser, mock_config)).to eq('custom context')
    end

    it 'allows take_screenshot to be overridden' do
      expect(custom_driver.take_screenshot(mock_page, screenshot_path)).to eq('screenshot taken')
    end

    it 'allows start_trace to be overridden' do
      expect(custom_driver.start_trace(mock_context)).to eq('trace started')
    end

    it 'allows stop_trace to be overridden' do
      expect(custom_driver.stop_trace(mock_context, trace_path)).to eq('trace stopped')
    end
  end

  describe 'inheritance' do
    it 'is a class' do
      expect(described_class).to be_a(Class)
    end

    it 'can be subclassed' do
      subclass = Class.new(described_class)
      expect(subclass).to be < described_class
    end
  end
end
