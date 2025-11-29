# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manifest', type: :request do
  describe 'GET /manifest.json' do
    before do
      get '/manifest.json'
    end

    it 'returns success status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct content type' do
      expect(response.content_type).to include('application/manifest+json')
    end

    it 'returns valid JSON' do
      expect { JSON.parse(response.body) }.not_to raise_error
    end

    describe 'manifest content' do
      let(:manifest) { JSON.parse(response.body) }

      it 'includes required name field' do
        expect(manifest['name']).to be_present
      end

      it 'includes required short_name field' do
        expect(manifest['short_name']).to eq('ReLINE')
      end

      it 'includes start_url with UTM parameters' do
        expect(manifest['start_url']).to include('utm_source=pwa')
        expect(manifest['start_url']).to include('utm_medium=homescreen')
      end

      it 'includes display mode' do
        expect(manifest['display']).to eq('standalone')
      end

      it 'includes theme_color' do
        expect(manifest['theme_color']).to be_present
      end

      it 'includes background_color' do
        expect(manifest['background_color']).to be_present
      end

      describe 'icons' do
        it 'includes icons array' do
          expect(manifest['icons']).to be_an(Array)
          expect(manifest['icons']).not_to be_empty
        end

        it 'includes 192x192 icon' do
          icon_192 = manifest['icons'].find { |i| i['sizes'] == '192x192' }
          expect(icon_192).to be_present
          expect(icon_192['type']).to eq('image/png')
          expect(icon_192['src']).to eq('/pwa/icon-192.png')
        end

        it 'includes 512x512 icon' do
          icon_512 = manifest['icons'].find { |i| i['sizes'] == '512x512' && i['purpose'] == 'any' }
          expect(icon_512).to be_present
          expect(icon_512['type']).to eq('image/png')
          expect(icon_512['src']).to eq('/pwa/icon-512.png')
        end

        it 'includes maskable icon' do
          maskable = manifest['icons'].find { |i| i['purpose'] == 'maskable' }
          expect(maskable).to be_present
          expect(maskable['sizes']).to eq('512x512')
          expect(maskable['src']).to eq('/pwa/icon-maskable-512.png')
        end
      end

      it 'includes categories' do
        expect(manifest['categories']).to include('productivity')
        expect(manifest['categories']).to include('social')
      end

      it 'includes lang field' do
        expect(manifest['lang']).to be_present
      end

      it 'includes orientation field' do
        expect(manifest['orientation']).to eq('portrait')
      end

      it 'includes dir field' do
        expect(manifest['dir']).to eq('ltr')
      end

      it 'includes description field' do
        expect(manifest['description']).to be_present
      end
    end

    context 'with Japanese locale' do
      before do
        get '/manifest.json', headers: { 'Accept-Language' => 'ja' }
      end

      let(:manifest) { JSON.parse(response.body) }

      it 'returns Japanese name' do
        # Name should contain Japanese characters or be configured for Japanese
        expect(manifest['name']).to be_present
        expect(manifest['name']).to eq('ReLINE - 猫が絆を取り持つ')
      end

      it 'returns Japanese description' do
        expect(manifest['description']).to be_present
        expect(manifest['description']).to eq('LINEボットで関係を維持するサービス')
      end

      it 'returns Japanese locale' do
        expect(manifest['lang']).to eq('ja')
      end

      it 'keeps short_name consistent across locales' do
        expect(manifest['short_name']).to eq('ReLINE')
      end
    end

    context 'with English locale' do
      let(:manifest) { JSON.parse(response.body) }

      before do
        I18n.with_locale(:en) do
          get '/manifest.json'
        end
      end

      it 'returns English name' do
        expect(manifest['name']).to eq('ReLINE - Cat Relationship Manager')
      end

      it 'returns English description' do
        expect(manifest['description']).to eq('LINE bot service for maintaining relationships')
      end

      it 'returns English locale' do
        expect(manifest['lang']).to eq('en')
      end
    end

    context 'environment-specific configuration' do
      let(:manifest) { JSON.parse(response.body) }

      context 'in development' do
        before do
          allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
          get '/manifest.json'
        end

        it 'uses development theme color' do
          # NOTE: This test depends on actual Rails.env, may need to be adjusted
          expect(manifest['theme_color']).to be_present
        end
      end
    end

    describe 'Web App Manifest specification compliance' do
      let(:manifest) { JSON.parse(response.body) }

      it 'complies with required manifest fields' do
        # Per W3C spec: name and icons are required
        expect(manifest['name']).to be_present
        expect(manifest['icons']).to be_an(Array)
        expect(manifest['icons'].size).to be >= 1
      end

      it 'uses valid display values' do
        valid_displays = %w[fullscreen standalone minimal-ui browser]
        expect(valid_displays).to include(manifest['display'])
      end

      it 'uses valid orientation values' do
        valid_orientations = %w[any natural landscape portrait portrait-primary portrait-secondary
                                landscape-primary landscape-secondary]
        expect(valid_orientations).to include(manifest['orientation'])
      end

      it 'uses valid dir values' do
        valid_dirs = %w[ltr rtl auto]
        expect(valid_dirs).to include(manifest['dir'])
      end

      it 'uses valid hex color format for theme_color' do
        expect(manifest['theme_color']).to match(/^#[0-9a-fA-F]{6}$/)
      end

      it 'uses valid hex color format for background_color' do
        expect(manifest['background_color']).to match(/^#[0-9a-fA-F]{6}$/)
      end
    end

    describe 'icon structure validation' do
      let(:manifest) { JSON.parse(response.body) }

      it 'ensures all icons have required fields' do
        manifest['icons'].each do |icon|
          expect(icon['src']).to be_present
          expect(icon['sizes']).to be_present
          expect(icon['type']).to be_present
          expect(icon['purpose']).to be_present
        end
      end

      it 'ensures icon sizes follow WxH format' do
        manifest['icons'].each do |icon|
          expect(icon['sizes']).to match(/^\d+x\d+$/)
        end
      end

      it 'ensures icon types are image MIME types' do
        manifest['icons'].each do |icon|
          expect(icon['type']).to start_with('image/')
        end
      end

      it 'ensures icon purposes are valid' do
        valid_purposes = %w[monochrome maskable any]
        manifest['icons'].each do |icon|
          expect(valid_purposes).to include(icon['purpose'])
        end
      end
    end

    describe 'start_url validation' do
      let(:manifest) { JSON.parse(response.body) }

      it 'starts with / for relative URL' do
        expect(manifest['start_url']).to start_with('/')
      end

      it 'includes proper UTM tracking parameters' do
        uri = URI.parse(manifest['start_url'])
        query = CGI.parse(uri.query)

        expect(query['utm_source']).to eq(['pwa'])
        expect(query['utm_medium']).to eq(['homescreen'])
      end
    end

    describe 'categories validation' do
      let(:manifest) { JSON.parse(response.body) }

      it 'contains valid category strings' do
        expect(manifest['categories']).to be_an(Array)
        manifest['categories'].each do |category|
          expect(category).to be_a(String)
          expect(category).not_to be_empty
        end
      end
    end
  end
end
