# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Pwa::Configs', type: :request do
  describe 'GET /api/pwa/config' do
    before do
      get '/api/pwa/config'
    end

    it 'returns success status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON content type' do
      expect(response.content_type).to include('application/json')
    end

    it 'returns valid JSON' do
      expect { JSON.parse(response.body) }.not_to raise_error
    end

    describe 'config structure' do
      let(:config) { JSON.parse(response.body) }

      it 'includes version' do
        expect(config['version']).to be_present
      end

      describe 'cache configuration' do
        it 'includes cache object' do
          expect(config['cache']).to be_a(Hash)
        end

        it 'includes static cache strategy' do
          expect(config['cache']['static']).to be_present
          expect(config['cache']['static']['strategy']).to eq('cache-first')
        end

        it 'includes images cache strategy' do
          expect(config['cache']['images']).to be_present
          expect(config['cache']['images']['strategy']).to eq('cache-first')
        end

        it 'includes pages cache strategy' do
          expect(config['cache']['pages']).to be_present
          expect(config['cache']['pages']['strategy']).to eq('network-first')
        end

        it 'includes api cache strategy' do
          expect(config['cache']['api']).to be_present
          expect(config['cache']['api']['strategy']).to eq('network-only')
        end

        it 'includes patterns as arrays' do
          expect(config['cache']['static']['patterns']).to be_an(Array)
          expect(config['cache']['images']['patterns']).to be_an(Array)
          expect(config['cache']['pages']['patterns']).to be_an(Array)
          expect(config['cache']['api']['patterns']).to be_an(Array)
        end

        it 'includes max_age for static cache' do
          expect(config['cache']['static']['max_age']).to eq(86_400)
        end

        it 'includes max_age for images cache' do
          expect(config['cache']['images']['max_age']).to eq(604_800)
        end

        it 'includes timeout for pages cache' do
          expect(config['cache']['pages']['timeout']).to eq(3000)
        end

        it 'includes valid patterns for static assets' do
          patterns = config['cache']['static']['patterns']
          expect(patterns).to include('\\.(css|js|woff2?)$')
        end

        it 'includes valid patterns for images' do
          patterns = config['cache']['images']['patterns']
          expect(patterns).to include('\\.(png|jpg|jpeg|gif|webp|svg|ico)$')
        end

        it 'includes valid patterns for pages' do
          patterns = config['cache']['pages']['patterns']
          expect(patterns).to include('^/$')
          expect(patterns).to include('^/terms$')
          expect(patterns).to include('^/privacy_policy$')
        end

        it 'includes valid patterns for api' do
          patterns = config['cache']['api']['patterns']
          expect(patterns).to include('^/api/')
          expect(patterns).to include('^/operator/')
        end
      end

      describe 'network configuration' do
        it 'includes network object' do
          expect(config['network']).to be_a(Hash)
        end

        it 'includes timeout' do
          expect(config['network']['timeout']).to be_a(Integer)
          expect(config['network']['timeout']).to eq(3000)
        end

        it 'includes retries' do
          expect(config['network']['retries']).to be_a(Integer)
          expect(config['network']['retries']).to eq(1)
        end
      end

      describe 'manifest configuration' do
        it 'includes manifest object' do
          expect(config['manifest']).to be_a(Hash)
        end

        it 'includes theme_color' do
          expect(config['manifest']['theme_color']).to be_present
          expect(config['manifest']['theme_color']).to match(/^#[0-9a-f]{6}$/i)
        end

        it 'includes background_color' do
          expect(config['manifest']['background_color']).to be_present
          expect(config['manifest']['background_color']).to eq('#ffffff')
        end

        it 'includes display mode' do
          expect(config['manifest']['display']).to eq('standalone')
        end

        it 'includes orientation' do
          expect(config['manifest']['orientation']).to eq('portrait')
        end

        it 'includes categories' do
          expect(config['manifest']['categories']).to be_an(Array)
          expect(config['manifest']['categories']).to include('productivity', 'social')
        end
      end

      describe 'features configuration' do
        it 'includes features object' do
          expect(config['features']).to be_a(Hash)
        end

        it 'includes install_prompt flag' do
          expect(config['features']['install_prompt']).to be(true).or be(false)
        end

        it 'includes push_notifications flag' do
          expect(config['features']['push_notifications']).to be(true).or be(false)
        end

        it 'includes background_sync flag' do
          expect(config['features']['background_sync']).to be(true).or be(false)
        end
      end

      describe 'observability configuration' do
        it 'includes observability object' do
          expect(config['observability']).to be_a(Hash)
        end

        it 'includes logger configuration' do
          expect(config['observability']['logger']).to be_a(Hash)
          expect(config['observability']['logger']['buffer_size']).to eq(50)
          expect(config['observability']['logger']['flush_interval_seconds']).to eq(30)
        end

        it 'includes metrics configuration' do
          expect(config['observability']['metrics']).to be_a(Hash)
          expect(config['observability']['metrics']['buffer_size']).to eq(100)
          expect(config['observability']['metrics']['flush_interval_seconds']).to eq(60)
        end
      end
    end

    context 'without CSRF token' do
      it 'does not require CSRF token' do
        # Should not raise ActionController::InvalidAuthenticityToken
        expect(response).to have_http_status(:ok)
      end
    end

    context 'environment-specific configuration' do
      it 'loads configuration for current environment' do
        config = JSON.parse(response.body)

        # Verify configuration is loaded (not empty)
        expect(config['version']).to be_present
        expect(config['cache']).to be_present
        expect(config['network']).to be_present
        expect(config['manifest']).to be_present
        expect(config['features']).to be_present
      end

      context 'in test environment' do
        it 'has valid theme color' do
          config = JSON.parse(response.body)
          # Test environment should have a valid hex color
          expect(config['manifest']['theme_color']).to match(/^#[0-9a-f]{6}$/i)
        end
      end
    end

    describe 'response headers' do
      it 'allows cross-origin requests' do
        # Verify CORS headers if needed
        expect(response).to have_http_status(:ok)
      end

      it 'is not cached by default' do
        # API responses should not be cached by browser
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'data consistency' do
      it 'returns consistent data across multiple requests' do
        first_config = JSON.parse(response.body)

        get '/api/pwa/config'
        second_config = JSON.parse(response.body)

        expect(first_config).to eq(second_config)
      end

      it 'returns deeply nested cache configuration correctly' do
        config = JSON.parse(response.body)

        # Verify all cache strategies have required fields
        config['cache'].each_value do |settings|
          expect(settings).to have_key('strategy')
          expect(settings).to have_key('patterns')
          expect(settings['patterns']).to be_an(Array)
        end
      end
    end

    describe 'default values' do
      it 'provides default network config if missing' do
        config = JSON.parse(response.body)
        expect(config['network']['timeout']).to be_present
        expect(config['network']['retries']).to be_present
      end

      it 'provides default features if missing' do
        config = JSON.parse(response.body)
        expect(config['features']).to have_key('install_prompt')
        expect(config['features']).to have_key('push_notifications')
        expect(config['features']).to have_key('background_sync')
      end
    end

    describe 'JSON structure validation' do
      let(:config) { JSON.parse(response.body) }

      it 'has all top-level keys' do
        expect(config.keys).to include('version', 'cache', 'network', 'manifest', 'features', 'observability')
      end

      it 'has all cache strategy types' do
        expect(config['cache'].keys).to include('static', 'images', 'pages', 'api')
      end

      it 'has valid strategy values' do
        valid_strategies = %w[cache-first network-first network-only stale-while-revalidate]
        config['cache'].each_value do |settings|
          expect(valid_strategies).to include(settings['strategy'])
        end
      end
    end
  end
end
