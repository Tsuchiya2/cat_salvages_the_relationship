# frozen_string_literal: true

# Utility for migrating passwords from Sorcery to has_secure_password
#
# This service provides utilities for migrating user passwords from the old
# Sorcery gem format (crypted_password) to Rails built-in has_secure_password
# format (password_digest). It supports both single record and batch migrations
# with comprehensive verification capabilities.
#
# @example Migrate a single user
#   user = User.find(123)
#   PasswordMigrator.migrate_single(user)
#
# @example Migrate all users in batches
#   migrated_count = PasswordMigrator.migrate_batch(User.all, batch_size: 500)
#   puts "Migrated #{migrated_count} users"
#
# @example Verify migration was successful
#   user = User.find(123)
#   PasswordMigrator.verify_migration(user) # => true or false
#
# @example Check if all users have been migrated
#   PasswordMigrator.migration_complete?(User) # => true or false
class PasswordMigrator
  class << self
    # Migrate a single user's password from crypted_password to password_digest
    #
    # Copies the crypted_password value to password_digest if not already migrated.
    # This is a direct column copy without re-hashing, as the password is already
    # properly hashed in Sorcery format.
    #
    # @param user [ActiveRecord::Base] User record to migrate
    # @return [Boolean] true if migration was performed, false if skipped
    #   - Returns false if crypted_password is blank (no password to migrate)
    #   - Returns true if password_digest is already present (already migrated)
    #   - Returns true if migration was successfully performed
    #
    # @example Migrate a single user
    #   user = User.find(123)
    #   PasswordMigrator.migrate_single(user)
    #   # => true (migration performed)
    #
    # @example User already migrated
    #   user = User.find(456)
    #   PasswordMigrator.migrate_single(user)
    #   # => true (already migrated, skipped)
    #
    # @example User with no password
    #   user = User.new(email: 'test@example.com')
    #   PasswordMigrator.migrate_single(user)
    #   # => false (no password to migrate)
    def migrate_single(user)
      return false if user.crypted_password.blank?
      return true if user.password_digest.present? # Already migrated

      user.password_digest = user.crypted_password
      user.save(validate: false)
    end

    # Migrate a batch of users
    #
    # Iterates through users in batches and migrates each one.
    # Uses find_each for memory-efficient iteration over large datasets.
    #
    # @param users [ActiveRecord::Relation] User relation to migrate
    # @param batch_size [Integer] Number of records to load per batch (default: 1000)
    # @return [Integer] Count of successfully migrated users
    #
    # @example Migrate all users
    #   migrated_count = PasswordMigrator.migrate_batch(User.all)
    #   puts "Migrated #{migrated_count} users"
    #
    # @example Migrate with custom batch size
    #   migrated_count = PasswordMigrator.migrate_batch(User.all, batch_size: 500)
    #
    # @example Migrate only unmigrated users
    #   unmigrated = User.where(password_digest: nil).where.not(crypted_password: nil)
    #   migrated_count = PasswordMigrator.migrate_batch(unmigrated)
    def migrate_batch(users, batch_size: 1000)
      migrated_count = 0
      users.find_each(batch_size: batch_size) do |user|
        migrated_count += 1 if migrate_single(user)
      end
      migrated_count
    end

    # Verify a user's migration was successful
    #
    # Checks that the password_digest field is present and matches the
    # crypted_password value, confirming a successful migration.
    #
    # @param user [ActiveRecord::Base] User record to verify
    # @return [Boolean] true if migration is verified, false otherwise
    #   - Returns true if password_digest exists and equals crypted_password
    #   - Returns false if password_digest is missing
    #   - Returns false if password_digest doesn't match crypted_password
    #
    # @example Verify migrated user
    #   user = User.find(123)
    #   PasswordMigrator.verify_migration(user)
    #   # => true (migration verified)
    #
    # @example Verify unmigrated user
    #   user = User.new(crypted_password: 'hash', password_digest: nil)
    #   PasswordMigrator.verify_migration(user)
    #   # => false (not migrated)
    #
    # @example Verify corrupted migration
    #   user = User.new(crypted_password: 'hash1', password_digest: 'hash2')
    #   PasswordMigrator.verify_migration(user)
    #   # => false (hashes don't match)
    def verify_migration(user)
      user.password_digest.present? && user.password_digest == user.crypted_password
    end

    # Check if all users of a model class have been migrated
    #
    # Verifies that no users exist with a crypted_password but missing password_digest.
    # This is useful for confirming that a migration is complete before removing
    # the crypted_password column.
    #
    # @param model_class [Class] ActiveRecord model class to check
    # @return [Boolean] true if migration is complete, false otherwise
    #   - Returns true if all users with crypted_password also have password_digest
    #   - Returns false if any users have crypted_password but no password_digest
    #
    # @example Check if User migration is complete
    #   PasswordMigrator.migration_complete?(User)
    #   # => true (all users migrated)
    #
    # @example Check if Operator migration is complete
    #   PasswordMigrator.migration_complete?(Operator)
    #   # => false (some operators not migrated)
    #
    # @example Use before dropping crypted_password column
    #   if PasswordMigrator.migration_complete?(User)
    #     remove_column :users, :crypted_password
    #   else
    #     raise "Cannot drop crypted_password: migration incomplete"
    #   end
    def migration_complete?(model_class)
      model_class.where(password_digest: nil).where.not(crypted_password: nil).count.zero?
    end
  end
end
