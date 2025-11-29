# frozen_string_literal: true

# Manifests controller for Progressive Web App
#
# Dynamically generates manifest.json with internationalization support
# and environment-specific configuration.
#
# @see https://developer.mozilla.org/en-US/docs/Web/Manifest
class ManifestsController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /manifest.json
  #
  # Generates a Web App Manifest JSON with I18n support.
  # The manifest includes localized app name/description and
  # environment-specific theme colors from pwa_config.yml.
  #
  # @example Response (application/manifest+json)
  #   {
  #     "name": "ReLINE - Cat Relationship Manager",
  #     "short_name": "ReLINE",
  #     "description": "LINE bot service for maintaining relationships",
  #     "start_url": "/?utm_source=pwa&utm_medium=homescreen",
  #     "display": "standalone",
  #     "theme_color": "#0d6efd",
  #     "icons": [...]
  #   }
  def show
    render json: manifest_data, content_type: 'application/manifest+json'
  end

  private

  # Build manifest data hash
  #
  # Combines I18n translations, PWA config settings, and icon definitions
  # to create a valid Web App Manifest structure.
  #
  # @return [Hash] Manifest data structure
  def manifest_data
    {
      name: I18n.t('pwa.name'),
      short_name: I18n.t('pwa.short_name'),
      description: I18n.t('pwa.description'),
      start_url: '/?utm_source=pwa&utm_medium=homescreen',
      display: pwa_config.dig(:manifest, :display) || 'standalone',
      orientation: pwa_config.dig(:manifest, :orientation) || 'portrait',
      theme_color: pwa_config.dig(:manifest, :theme_color) || '#0d6efd',
      background_color: pwa_config.dig(:manifest, :background_color) || '#ffffff',
      lang: I18n.locale.to_s,
      dir: 'ltr',
      icons: icon_definitions,
      categories: pwa_config.dig(:manifest, :categories) || %w[productivity social]
    }
  end

  # Define icon array for manifest
  #
  # Specifies PWA icons with different sizes and purposes.
  # Icons should be created by PWA-001 task.
  #
  # @return [Array<Hash>] Array of icon definitions
  def icon_definitions
    [
      {
        src: '/pwa/icon-192.png',
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any'
      },
      {
        src: '/pwa/icon-512.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any'
      },
      {
        src: '/pwa/icon-maskable-512.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable'
      }
    ]
  end

  # Load PWA configuration from config/pwa_config.yml
  #
  # Configuration includes caching strategies, manifest properties,
  # and feature flags for different environments.
  #
  # @return [Hash] PWA configuration hash
  def pwa_config
    @pwa_config ||= Rails.application.config_for(:pwa_config)
  end
end
