# frozen_string_literal: true

# Validator for data migrations with checksums and integrity checks
#
# Provides utilities for validating data migrations to ensure data integrity
# during schema changes or data transformations.
#
# @example Validate password migration
#   DataMigrationValidator.validate_password_migration
#
# @example Generate checksums for validation
#   before_checksums = DataMigrationValidator.generate_checksum(Operator)
#   # Perform migration
#   after_checksums = DataMigrationValidator.generate_checksum(Operator)
#   DataMigrationValidator.validate_migration(before_checksums, after_checksums)
class DataMigrationValidator
  # Generate checksums for records to track data integrity
  #
  # Creates SHA256 checksums for each record based on authentication-related fields.
  # This allows tracking whether data has been modified during migration.
  #
  # @param model_class [Class] ActiveRecord model class to generate checksums for
  # @return [Array<String>] Array of SHA256 checksums, one per record
  #
  # @example
  #   checksums = DataMigrationValidator.generate_checksum(Operator)
  #   # => ["a1b2c3...", "d4e5f6...", ...]
  def self.generate_checksum(model_class)
    records = model_class.pluck(:id, :email, :crypted_password, :password_digest)
    records.map { |r| Digest::SHA256.hexdigest(r.join(':')) }
  end

  # Validate migration by comparing before and after checksums
  #
  # Ensures that records are not lost or corrupted during migration.
  # Raises an error if checksums don't match.
  #
  # @param before_checksums [Array<String>] Checksums before migration
  # @param after_checksums [Array<String>] Checksums after migration
  # @return [Boolean] true if migration is valid
  # @raise [RuntimeError] if checksums don't match
  #
  # @example
  #   before = DataMigrationValidator.generate_checksum(Operator)
  #   # Perform migration
  #   after = DataMigrationValidator.generate_checksum(Operator)
  #   DataMigrationValidator.validate_migration(before, after)
  def self.validate_migration(before_checksums, after_checksums)
    missing_count = before_checksums.size - after_checksums.size

    if missing_count.positive?
      raise "Migration validation failed: #{missing_count} records lost"
    elsif missing_count.negative?
      raise "Migration validation failed: #{missing_count.abs} unexpected records added"
    end

    # Check if all checksums still exist (order doesn't matter)
    before_set = before_checksums.to_set
    after_set = after_checksums.to_set

    missing_checksums = before_set - after_set
    raise "Migration validation failed: #{missing_checksums.size} records modified or corrupted" if missing_checksums.any?

    true
  end

  # Verify data integrity for a specific model
  #
  # Checks for common integrity issues like missing required fields
  # or inconsistent data states.
  #
  # @param model_class [Class] ActiveRecord model class to verify
  # @return [Hash] Hash with integrity check results
  #
  # @example
  #   result = DataMigrationValidator.verify_integrity(Operator)
  #   # => { valid: true, total_records: 10, issues: [] }
  def self.verify_integrity(model_class)
    total_records = model_class.count
    issues = []

    # Check for records with missing required authentication fields
    missing_auth = model_class.where(
      'crypted_password IS NULL AND password_digest IS NULL'
    ).count

    issues << "#{missing_auth} records missing authentication data" if missing_auth.positive?

    # Check for records with duplicate authentication methods
    duplicate_auth = model_class.where(
      'crypted_password IS NOT NULL AND password_digest IS NOT NULL'
    ).count

    issues << "#{duplicate_auth} records have both crypted_password and password_digest" if duplicate_auth.positive?

    {
      valid: issues.empty?,
      total_records: total_records,
      issues: issues
    }
  end

  # Validate password migration from Sorcery to BCrypt
  #
  # Ensures that all operators with old password format (crypted_password)
  # have been migrated to new format (password_digest).
  #
  # @return [Boolean] true if migration is complete
  # @raise [RuntimeError] if migration is incomplete
  #
  # @example
  #   DataMigrationValidator.validate_password_migration
  def self.validate_password_migration
    missing = Operator.where(password_digest: nil).where.not(crypted_password: nil).count

    raise "Migration incomplete: #{missing} operators missing password_digest" if missing.positive?

    true
  end
end
