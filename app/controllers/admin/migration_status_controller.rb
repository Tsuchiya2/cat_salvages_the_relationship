# frozen_string_literal: true

module Admin
  # Admin controller for migration status monitoring
  # Requires admin authentication
  class MigrationStatusController < ApplicationController
    before_action :require_admin

    # GET /admin/migration/status
    # Returns migration progress and status information
    def show
      progress = load_progress_data

      render json: {
        migration_in_progress: migration_in_progress?,
        progress: progress,
        current_database: current_database_info,
        timestamp: Time.current.iso8601
      }
    end

    private

    # Requires admin authentication
    def require_admin
      # Check if operator is logged in
      unless current_operator
        render json: { error: 'Authentication required' }, status: :unauthorized
        return
      end

      # Check if operator has admin role
      unless current_operator.admin?
        render json: { error: 'Admin access required' }, status: :forbidden
      end
    end

    # Gets current operator from session
    # @return [Operator, nil] current operator or nil
    def current_operator
      @current_operator ||= Operator.find_by(id: session[:operator_id])
    end

    # Checks if migration is in progress
    # @return [Boolean] true if migration flag file exists
    def migration_in_progress?
      File.exist?(Rails.root.join('tmp/migration_in_progress'))
    end

    # Loads progress data from file
    # @return [Hash] progress data or default status
    def load_progress_data
      progress_file = Rails.root.join('tmp/migration_progress.json')

      if File.exist?(progress_file)
        JSON.parse(File.read(progress_file), symbolize_names: true)
      else
        { status: 'not_started', message: 'No migration in progress' }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to load migration progress: #{e.message}"
      { status: 'error', message: 'Failed to load progress data' }
    end

    # Gets current database information
    # @return [Hash] database information
    def current_database_info
      {
        adapter: ActiveRecord::Base.connection.adapter_name,
        database: ActiveRecord::Base.connection.current_database,
        version: database_version
      }
    rescue StandardError => e
      { error: e.message }
    end

    # Gets database version
    # @return [String] database version
    def database_version
      case ActiveRecord::Base.connection.adapter_name.downcase
      when 'mysql2'
        ActiveRecord::Base.connection.select_value('SELECT VERSION()')
      when 'postgresql'
        ActiveRecord::Base.connection.select_value('SELECT VERSION()')
      else
        'unknown'
      end
    rescue StandardError
      'unknown'
    end
  end
end
