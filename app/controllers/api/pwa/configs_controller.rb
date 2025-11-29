# frozen_string_literal: true

module Api
  module Pwa
    # ConfigsController - Serves PWA configuration to Service Worker
    #
    # @api public
    # @example GET /api/pwa/config
    #   Response:
    #   {
    #     "version": "v1",
    #     "cache": { ... },
    #     "network": { ... },
    #     "manifest": { ... },
    #     "features": { ... }
    #   }
    class ConfigsController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/pwa/config
      # Returns PWA configuration as JSON
      def show
        render json: config_data, status: :ok
      end

      private

      # Build configuration data from pwa_config.yml
      # @return [Hash] Configuration hash
      def config_data
        {
          version: pwa_config[:version] || 'v1',
          cache: build_cache_config,
          network: pwa_config[:network] || default_network_config,
          manifest: pwa_config[:manifest] || {},
          features: pwa_config[:features] || default_features,
          observability: pwa_config[:observability] || {}
        }
      end

      # Build cache configuration with patterns as arrays
      # @return [Hash] Cache configuration
      def build_cache_config
        cache_config = pwa_config[:cache] || {}
        cache_config.transform_values do |settings|
          {
            strategy: settings[:strategy],
            patterns: Array(settings[:patterns]),
            max_age: settings[:max_age],
            timeout: settings[:timeout]
          }.compact
        end
      end

      # Load PWA configuration from config file
      # @return [HashWithIndifferentAccess] Configuration
      def pwa_config
        @pwa_config ||= Rails.application.config_for(:pwa_config)
      end

      # Default network configuration
      # @return [Hash]
      def default_network_config
        { timeout: 3000, retries: 1 }
      end

      # Default feature flags
      # @return [Hash]
      def default_features
        { install_prompt: true, push_notifications: false, background_sync: false }
      end
    end
  end
end
