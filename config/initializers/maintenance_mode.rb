# frozen_string_literal: true

# Maintenance Mode Configuration
#
# This module checks if the application is in maintenance mode
# by detecting the presence of a specific file
module MaintenanceMode
  # Path to maintenance mode flag file
  MAINTENANCE_FILE = Rails.root.join('tmp', 'maintenance.txt').freeze

  # Checks if maintenance mode is enabled
  # @return [Boolean] true if maintenance mode is active
  def self.enabled?
    File.exist?(MAINTENANCE_FILE)
  end

  # Enables maintenance mode by creating the flag file
  # @param message [String] optional custom maintenance message
  def self.enable!(message: nil)
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.write(MAINTENANCE_FILE, message || default_message)
    Rails.logger.info 'Maintenance mode enabled'
  end

  # Disables maintenance mode by removing the flag file
  def self.disable!
    File.delete(MAINTENANCE_FILE) if enabled?
    Rails.logger.info 'Maintenance mode disabled'
  end

  # Gets the maintenance message from the file
  # @return [String] maintenance message
  def self.message
    enabled? ? File.read(MAINTENANCE_FILE) : nil
  end

  # Default maintenance message
  def self.default_message
    'System maintenance in progress. Please check back soon.'
  end
end
