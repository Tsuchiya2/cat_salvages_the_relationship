# frozen_string_literal: true

# Authenticatable Concern
#
# Generic concern that can be reused for multiple user models (Operator, Admin, Customer, etc.)
# Provides configuration for authentication behavior through the `authenticates_with` class method.
#
# Usage:
#   class Operator < ApplicationRecord
#     include Authenticatable
#     authenticates_with model: Operator, path_prefix: 'operator'
#   end
#
#   class Admin < ApplicationRecord
#     include Authenticatable
#     authenticates_with model: Admin, path_prefix: 'admin'
#   end
#
# This concern serves as the foundation for multi-model authentication patterns,
# allowing different user types to share authentication configuration while maintaining
# separate routes and behaviors.
module Authenticatable
  extend ActiveSupport::Concern

  class_methods do
    # Configure authentication settings for the model
    #
    # @param model [Class] The model class being authenticated (e.g., Operator, Admin)
    # @param path_prefix [String, nil] URL path prefix for routes (e.g., 'operator', 'admin')
    #
    # @example
    #   authenticates_with model: Operator, path_prefix: 'operator'
    #   # Sets up authentication for Operator model with /operator/* routes
    #
    # @example
    #   authenticates_with model: Admin
    #   # Sets up authentication for Admin model without specific path prefix
    def authenticates_with(model:, path_prefix: nil)
      @authenticated_model = model
      @path_prefix = path_prefix
    end

    # Returns the configured authentication model
    #
    # @return [Class] The model class configured for authentication
    attr_reader :authenticated_model

    # Returns the configured path prefix for routes
    #
    # @return [String, nil] The path prefix or nil if not configured
    attr_reader :path_prefix
  end

  # Instance methods for authentication helpers
  # These can be extended in future iterations with methods like:
  # - authenticated?
  # - login_path
  # - logout_path
  # - session_key
end
