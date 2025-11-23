# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../../lib/testing/playwright_configuration'

RSpec.describe Testing::PlaywrightConfiguration do
  # Mock PathUtils and EnvUtils before each test
  before do
    # Mock PathUtils
    allow(Testing::Utils::PathUtils).to receive(:screenshots_path)
      .and_return(Pathname.new(Dir.mktmpdir))
    allow(Testing::Utils::PathUtils).to receive(:traces_path)
      .and_return(Pathname.new(Dir.mktmpdir))
  end

  describe 'constants' do
    it 'defines DEFAULT_BROWSER' do
      expect(described_class::DEFAULT_BROWSER).to eq('chromium')
    end

    it 'defines DEFAULT_HEADLESS' do
      expect(described_class::DEFAULT_HEADLESS).to eq(true)
    end

    it 'defines DEFAULT_VIEWPORT_WIDTH' do
      expect(described_class::DEFAULT_VIEWPORT_WIDTH).to eq(1920)
    end

    it 'defines DEFAULT_VIEWPORT_HEIGHT' do
      expect(described_class::DEFAULT_VIEWPORT_HEIGHT).to eq(1080)
    end

    it 'defines DEFAULT_TIMEOUT' do
      expect(described_class::DEFAULT_TIMEOUT).to eq(30_000)
    end

    it 'defines DEFAULT_SLOW_MO' do
      expect(described_class::DEFAULT_SLOW_MO).to eq(0)
    end

    it 'defines DEFAULT_TRACE_MODE' do
      expect(described_class::DEFAULT_TRACE_MODE).to eq('off')
    end

    it 'defines VALID_BROWSERS' do
      expect(described_class::VALID_BROWSERS).to eq(%w[chromium firefox webkit])
    end

    it 'defines VALID_TRACE_MODES' do
      expect(described_class::VALID_TRACE_MODES).to eq(%w[on off on-first-retry])
    end
  end

  describe '.for_environment' do
    context 'when in CI environment' do
      before do
        allow(Testing::Utils::EnvUtils).to receive(:ci_environment?).and_return(true)
        allow(Testing::Utils::EnvUtils).to receive(:environment).and_return('test')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
      end

      it 'returns CI configuration' do
        config = described_class.for_environment

        expect(config.browser_type).to eq('chromium')
        expect(config.headless).to be(true)
        expect(config.timeout).to eq(60_000)
        expect(config.trace_mode).to eq('on-first-retry')
      end
    end

    context 'when in development environment' do
      before do
        allow(Testing::Utils::EnvUtils).to receive(:ci_environment?).and_return(false)
        allow(Testing::Utils::EnvUtils).to receive(:environment).and_return('development')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '500').and_return('500')
      end

      it 'returns development configuration' do
        config = described_class.for_environment

        expect(config.browser_type).to eq('chromium')
        expect(config.headless).to be(false)
        expect(config.slow_mo).to eq(500)
        expect(config.trace_mode).to eq('on')
      end
    end

    context 'when in test environment (local)' do
      before do
        allow(Testing::Utils::EnvUtils).to receive(:ci_environment?).and_return(false)
        allow(Testing::Utils::EnvUtils).to receive(:environment).and_return('test')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_HEADLESS', 'true').and_return('true')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '0').and_return('0')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_TRACE_MODE', 'off').and_return('off')
      end

      it 'returns local configuration' do
        config = described_class.for_environment

        expect(config.browser_type).to eq('chromium')
        expect(config.headless).to be(true)
        expect(config.timeout).to eq(30_000)
        expect(config.trace_mode).to eq('off')
      end
    end

    context 'when environment is explicitly passed' do
      before do
        allow(Testing::Utils::EnvUtils).to receive(:ci_environment?).and_return(false)
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '500').and_return('500')
      end

      it 'uses the passed environment' do
        config = described_class.for_environment('development')

        expect(config.headless).to be(false)
        expect(config.trace_mode).to eq('on')
      end
    end
  end

  describe '.ci_config' do
    before do
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
    end

    it 'returns CI-optimized configuration' do
      config = described_class.ci_config

      expect(config.browser_type).to eq('chromium')
      expect(config.headless).to be(true)
      expect(config.timeout).to eq(60_000)
      expect(config.slow_mo).to eq(0)
      expect(config.trace_mode).to eq('on-first-retry')
    end

    it 'respects PLAYWRIGHT_BROWSER environment variable' do
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('firefox')

      config = described_class.ci_config

      expect(config.browser_type).to eq('firefox')
    end

    it 'uses default viewport size' do
      config = described_class.ci_config

      expect(config.viewport).to eq(
        width: 1920,
        height: 1080
      )
    end
  end

  describe '.local_config' do
    before do
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_HEADLESS', 'true').and_return('true')
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '0').and_return('0')
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_TRACE_MODE', 'off').and_return('off')
    end

    it 'returns local testing configuration' do
      config = described_class.local_config

      expect(config.browser_type).to eq('chromium')
      expect(config.headless).to be(true)
      expect(config.timeout).to eq(30_000)
      expect(config.trace_mode).to eq('off')
    end

    context 'with environment variables' do
      it 'respects PLAYWRIGHT_BROWSER' do
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('webkit')

        config = described_class.local_config

        expect(config.browser_type).to eq('webkit')
      end

      it 'respects PLAYWRIGHT_HEADLESS=false' do
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_HEADLESS', 'true').and_return('false')

        config = described_class.local_config

        expect(config.headless).to be(false)
      end

      it 'respects PLAYWRIGHT_SLOW_MO' do
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '0').and_return('300')

        config = described_class.local_config

        expect(config.slow_mo).to eq(300)
      end

      it 'respects PLAYWRIGHT_TRACE_MODE' do
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_TRACE_MODE', 'off').and_return('on')

        config = described_class.local_config

        expect(config.trace_mode).to eq('on')
      end
    end
  end

  describe '.development_config' do
    before do
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return('chromium')
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '500').and_return('500')
    end

    it 'returns development configuration' do
      config = described_class.development_config

      expect(config.browser_type).to eq('chromium')
      expect(config.headless).to be(false)
      expect(config.slow_mo).to eq(500)
      expect(config.timeout).to eq(30_000)
      expect(config.trace_mode).to eq('on')
    end

    it 'always uses headed mode' do
      config = described_class.development_config

      expect(config.headless).to be(false)
    end

    it 'always captures trace' do
      config = described_class.development_config

      expect(config.trace_mode).to eq('on')
    end

    it 'respects PLAYWRIGHT_SLOW_MO override' do
      allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '500').and_return('1000')

      config = described_class.development_config

      expect(config.slow_mo).to eq(1000)
    end
  end

  describe '#initialize' do
    let(:valid_params) do
      {
        browser_type: 'chromium',
        headless: true,
        viewport: { width: 1920, height: 1080 },
        slow_mo: 0,
        timeout: 30_000,
        trace_mode: 'off'
      }
    end

    it 'initializes with valid parameters' do
      config = described_class.new(**valid_params)

      expect(config.browser_type).to eq('chromium')
      expect(config.headless).to be(true)
      expect(config.viewport).to eq(width: 1920, height: 1080)
      expect(config.slow_mo).to eq(0)
      expect(config.timeout).to eq(30_000)
      expect(config.trace_mode).to eq('off')
    end

    it 'sets screenshots_path from PathUtils' do
      screenshots_path = Pathname.new('/tmp/screenshots')
      allow(Testing::Utils::PathUtils).to receive(:screenshots_path).and_return(screenshots_path)

      config = described_class.new(**valid_params)

      expect(config.screenshots_path).to eq(screenshots_path)
    end

    it 'sets traces_path from PathUtils' do
      traces_path = Pathname.new('/tmp/traces')
      allow(Testing::Utils::PathUtils).to receive(:traces_path).and_return(traces_path)

      config = described_class.new(**valid_params)

      expect(config.traces_path).to eq(traces_path)
    end

    context 'validation' do
      it 'raises ArgumentError for invalid browser_type' do
        expect do
          described_class.new(**valid_params.merge(browser_type: 'invalid'))
        end.to raise_error(
          ArgumentError,
          /Invalid browser_type: invalid/
        )
      end

      it 'raises ArgumentError for invalid trace_mode' do
        expect do
          described_class.new(**valid_params.merge(trace_mode: 'invalid'))
        end.to raise_error(
          ArgumentError,
          /Invalid trace_mode: invalid/
        )
      end

      it 'includes valid options in error message for browser_type' do
        expect do
          described_class.new(**valid_params.merge(browser_type: 'safari'))
        end.to raise_error(
          ArgumentError,
          /Valid options: chromium, firefox, webkit/
        )
      end

      it 'includes valid options in error message for trace_mode' do
        expect do
          described_class.new(**valid_params.merge(trace_mode: 'always'))
        end.to raise_error(
          ArgumentError,
          /Valid options: on, off, on-first-retry/
        )
      end
    end

    context 'directory creation' do
      it 'creates screenshots directory' do
        screenshots_path = Pathname.new(Dir.mktmpdir)
        allow(Testing::Utils::PathUtils).to receive(:screenshots_path).and_return(screenshots_path)
        allow(FileUtils).to receive(:mkdir_p)

        described_class.new(**valid_params)

        expect(FileUtils).to have_received(:mkdir_p).with(screenshots_path)
      end

      it 'creates traces directory' do
        traces_path = Pathname.new(Dir.mktmpdir)
        allow(Testing::Utils::PathUtils).to receive(:traces_path).and_return(traces_path)
        allow(FileUtils).to receive(:mkdir_p)

        described_class.new(**valid_params)

        expect(FileUtils).to have_received(:mkdir_p).with(traces_path)
      end
    end
  end

  describe '#browser_launch_options' do
    let(:config) do
      described_class.new(
        browser_type: 'chromium',
        headless: true,
        viewport: { width: 1920, height: 1080 },
        slow_mo: 100,
        timeout: 45_000,
        trace_mode: 'on'
      )
    end

    it 'returns correct launch options' do
      options = config.browser_launch_options

      expect(options).to eq(
        headless: true,
        timeout: 45_000,
        slowMo: 100
      )
    end

    it 'uses camelCase for slowMo' do
      options = config.browser_launch_options

      expect(options).to have_key(:slowMo)
      expect(options).not_to have_key(:slow_mo)
    end
  end

  describe '#browser_context_options' do
    let(:screenshots_path) { Pathname.new('/tmp/screenshots') }
    let(:config) do
      allow(Testing::Utils::PathUtils).to receive(:screenshots_path).and_return(screenshots_path)

      described_class.new(
        browser_type: 'chromium',
        headless: true,
        viewport: { width: 1280, height: 720 },
        slow_mo: 0,
        timeout: 30_000,
        trace_mode: 'off'
      )
    end

    it 'returns correct context options' do
      options = config.browser_context_options

      expect(options).to eq(
        viewport: { width: 1280, height: 720 },
        recordVideo: {
          dir: screenshots_path.to_s
        }
      )
    end

    it 'converts screenshots_path to string for recordVideo' do
      options = config.browser_context_options

      expect(options[:recordVideo][:dir]).to be_a(String)
      expect(options[:recordVideo][:dir]).to eq(screenshots_path.to_s)
    end
  end

  describe 'browser type support' do
    %w[chromium firefox webkit].each do |browser|
      it "supports #{browser} browser" do
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_BROWSER', 'chromium').and_return(browser)
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_HEADLESS', 'true').and_return('true')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_SLOW_MO', '0').and_return('0')
        allow(Testing::Utils::EnvUtils).to receive(:get).with('PLAYWRIGHT_TRACE_MODE', 'off').and_return('off')

        config = described_class.local_config

        expect(config.browser_type).to eq(browser)
      end
    end
  end

  describe 'trace mode support' do
    %w[on off on-first-retry].each do |mode|
      it "supports #{mode} trace mode" do
        config = described_class.new(
          browser_type: 'chromium',
          headless: true,
          viewport: { width: 1920, height: 1080 },
          slow_mo: 0,
          timeout: 30_000,
          trace_mode: mode
        )

        expect(config.trace_mode).to eq(mode)
      end
    end
  end

  describe 'attribute readers' do
    let(:config) { described_class.ci_config }

    it 'has browser_type reader' do
      expect(config).to respond_to(:browser_type)
    end

    it 'has headless reader' do
      expect(config).to respond_to(:headless)
    end

    it 'has viewport reader' do
      expect(config).to respond_to(:viewport)
    end

    it 'has slow_mo reader' do
      expect(config).to respond_to(:slow_mo)
    end

    it 'has timeout reader' do
      expect(config).to respond_to(:timeout)
    end

    it 'has screenshots_path reader' do
      expect(config).to respond_to(:screenshots_path)
    end

    it 'has traces_path reader' do
      expect(config).to respond_to(:traces_path)
    end

    it 'has trace_mode reader' do
      expect(config).to respond_to(:trace_mode)
    end
  end
end
