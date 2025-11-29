# frozen_string_literal: true

# Data migration to copy password hashes from Sorcery to Rails 8 format
#
# Migrates passwords from Sorcery's `crypted_password` column to Rails 8's
# `password_digest` column. Both use bcrypt format, so hashes can be copied directly.
#
# Safety features:
# - Transaction wrapping for atomicity
# - Pre-migration validation (all operators must have crypted_password)
# - Post-migration validation (all operators must have password_digest)
# - Checksum-based integrity verification using DataMigrationValidator
# - Reversible (down method clears password_digest)
class MigrateSorceryPasswords < ActiveRecord::Migration[8.1]
  def up
    # Generate checksums before migration for integrity verification
    # Use ID and email only (exclude password fields as they will change)
    say_with_time 'Generating pre-migration checksums...' do
      @before_checksums = generate_stable_checksums
      @before_count = Operator.count
      @before_checksums.size
    end

    # Pre-migration validation: ensure all operators have crypted_password
    say_with_time 'Validating pre-migration state...' do
      missing_password = Operator.where(crypted_password: nil).count
      if missing_password.positive?
        raise "Pre-migration validation failed: #{missing_password} operators missing crypted_password"
      end
      Operator.count
    end

    # Migrate passwords in transaction for atomicity
    say_with_time 'Copying crypted_password to password_digest...' do
      Operator.transaction do
        migrated_count = 0
        Operator.find_each do |operator|
          # Copy bcrypt hash directly (formats are compatible)
          operator.update_column(:password_digest, operator.crypted_password)
          migrated_count += 1
        end
        migrated_count
      end
    end

    # Post-migration validation: ensure all operators have password_digest
    say_with_time 'Validating post-migration state...' do
      missing_digest = Operator.where(password_digest: nil).count
      if missing_digest.positive?
        raise "Post-migration validation failed: #{missing_digest} operators missing password_digest"
      end
      Operator.count
    end

    # Verify no records were lost or added during migration
    say_with_time 'Verifying migration integrity...' do
      @after_checksums = generate_stable_checksums
      @after_count = Operator.count

      # Check record count
      if @before_count != @after_count
        raise "Migration validation failed: record count changed (before: #{@before_count}, after: #{@after_count})"
      end

      # Check that all records still exist with same IDs and emails
      missing_checksums = @before_checksums - @after_checksums
      if missing_checksums.any?
        raise "Migration validation failed: #{missing_checksums.size} records lost or modified"
      end

      'Integrity verified'
    end

    # Final integrity check: verify password_digest matches crypted_password
    say_with_time 'Verifying password hash integrity...' do
      mismatched = Operator.where('password_digest != crypted_password').count
      if mismatched.positive?
        raise "Password hash validation failed: #{mismatched} operators have mismatched hashes"
      end
      'All password hashes match'
    end
  end

  private

  # Generate checksums based on stable fields (ID and email only)
  # Password fields are excluded as they will change during migration
  def generate_stable_checksums
    records = Operator.pluck(:id, :email, :name, :role)
    records.map { |r| Digest::SHA256.hexdigest(r.join(':')) }
  end

  def down
    # Rollback: clear password_digest column
    say_with_time 'Rolling back: clearing password_digest...' do
      Operator.update_all(password_digest: nil)
      Operator.count
    end
  end
end
