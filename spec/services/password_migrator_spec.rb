# frozen_string_literal: true

require 'rails_helper'

# Create the test table once when the file is loaded
# This is more efficient than creating/dropping for each test
RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table :password_migrator_test_users, force: true do |t|
        t.string :email, null: false
        t.string :name, null: false
        t.string :crypted_password
        t.string :password_digest
        t.timestamps
      end
    end
  end

  config.after(:suite) do
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      drop_table :password_migrator_test_users, if_exists: true
    end
  end
end

RSpec.describe PasswordMigrator do
  # Define temporary model for testing
  let(:test_user_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'password_migrator_test_users'
    end
  end

  # Stub the constant for the tests
  before do
    stub_const('TestUser', test_user_class)
    TestUser.delete_all
  end

  describe '.migrate_single' do
    let!(:user) do
      TestUser.create!(
        name: 'Test User',
        email: 'user@example.com',
        crypted_password: nil,
        password_digest: nil
      )
    end

    context 'when user has crypted_password but no password_digest' do
      before do
        # Simulate old Sorcery format
        user.update!(
          crypted_password: 'old_sorcery_hash',
          password_digest: nil
        )
      end

      it 'migrates password to password_digest' do
        result = described_class.migrate_single(user)

        expect(result).to be true
        user.reload
        expect(user.password_digest).to eq('old_sorcery_hash')
      end

      it 'does not modify crypted_password' do
        original_crypted_password = user.crypted_password
        described_class.migrate_single(user)

        user.reload
        expect(user.crypted_password).to eq(original_crypted_password)
      end
    end

    context 'when user already has password_digest' do
      before do
        # Simulate already migrated user
        user.update!(
          crypted_password: 'old_sorcery_hash',
          password_digest: 'already_migrated_hash'
        )
      end

      it 'returns true without changing anything' do
        result = described_class.migrate_single(user)

        expect(result).to be true
        user.reload
        expect(user.password_digest).to eq('already_migrated_hash')
      end

      it 'does not overwrite existing password_digest' do
        original_digest = user.password_digest
        described_class.migrate_single(user)

        user.reload
        expect(user.password_digest).to eq(original_digest)
      end
    end

    context 'when user has no crypted_password' do
      before do
        # Simulate user with no password
        user.update!(
          crypted_password: nil,
          password_digest: nil
        )
      end

      it 'returns false' do
        result = described_class.migrate_single(user)

        expect(result).to be false
      end

      it 'does not set password_digest' do
        described_class.migrate_single(user)

        user.reload
        expect(user.password_digest).to be_nil
      end
    end

    context 'when user has blank crypted_password' do
      before do
        user.update!(
          crypted_password: '',
          password_digest: nil
        )
      end

      it 'returns false' do
        result = described_class.migrate_single(user)

        expect(result).to be false
      end
    end
  end

  describe '.migrate_batch' do
    let!(:user1) do
      TestUser.create!(
        name: 'Test User 1',
        email: 'user1@example.com',
        crypted_password: 'hash1',
        password_digest: nil
      )
    end

    let!(:user2) do
      TestUser.create!(
        name: 'Test User 2',
        email: 'user2@example.com',
        crypted_password: 'hash2',
        password_digest: 'hash2'
      )
    end

    let!(:user3) do
      TestUser.create!(
        name: 'Test User 3',
        email: 'user3@example.com',
        crypted_password: nil,
        password_digest: nil
      )
    end

    it 'migrates all unmigrated users' do
      migrated_count = described_class.migrate_batch(TestUser.all)

      # user1: migrated (1)
      # user2: already migrated, returns true (1)
      # user3: no password, returns false (0)
      expect(migrated_count).to eq(2)
    end

    it 'sets password_digest for unmigrated users' do
      described_class.migrate_batch(TestUser.all)

      user1.reload
      expect(user1.password_digest).to eq('hash1')
    end

    it 'does not change already migrated users' do
      described_class.migrate_batch(TestUser.all)

      user2.reload
      expect(user2.password_digest).to eq('hash2')
    end

    it 'skips users with no password' do
      described_class.migrate_batch(TestUser.all)

      user3.reload
      expect(user3.password_digest).to be_nil
    end

    context 'with custom batch_size' do
      it 'respects the batch_size parameter' do
        allow(TestUser).to receive(:all).and_return(TestUser.all)
        allow(TestUser.all).to receive(:find_each).and_call_original

        described_class.migrate_batch(TestUser.all, batch_size: 2)

        expect(TestUser.all).to have_received(:find_each).with(batch_size: 2)
      end
    end

    context 'with empty relation' do
      it 'returns zero' do
        migrated_count = described_class.migrate_batch(TestUser.none)

        expect(migrated_count).to eq(0)
      end
    end

    context 'with only unmigrated users' do
      let!(:unmigrated_users) do
        TestUser.where(password_digest: nil).where.not(crypted_password: nil)
      end

      it 'migrates only unmigrated users' do
        migrated_count = described_class.migrate_batch(unmigrated_users)

        expect(migrated_count).to eq(1) # Only user1
      end
    end
  end

  describe '.verify_migration' do
    let!(:user) do
      TestUser.create!(
        name: 'Test User',
        email: 'user@example.com',
        crypted_password: nil,
        password_digest: nil
      )
    end

    context 'when migration is successful' do
      before do
        user.update!(
          crypted_password: 'test_hash',
          password_digest: 'test_hash'
        )
      end

      it 'returns true' do
        result = described_class.verify_migration(user)

        expect(result).to be true
      end
    end

    context 'when password_digest is missing' do
      before do
        user.update!(
          crypted_password: 'test_hash',
          password_digest: nil
        )
      end

      it 'returns false' do
        result = described_class.verify_migration(user)

        expect(result).to be false
      end
    end

    context 'when password_digest does not match crypted_password' do
      before do
        user.update!(
          crypted_password: 'hash1',
          password_digest: 'hash2'
        )
      end

      it 'returns false' do
        result = described_class.verify_migration(user)

        expect(result).to be false
      end
    end

    context 'when both fields are blank' do
      before do
        user.update!(
          crypted_password: nil,
          password_digest: nil
        )
      end

      it 'returns false' do
        result = described_class.verify_migration(user)

        expect(result).to be false
      end
    end

    context 'when password_digest is present but crypted_password is blank' do
      before do
        user.update!(
          crypted_password: nil,
          password_digest: 'some_hash'
        )
      end

      it 'returns false' do
        result = described_class.verify_migration(user)

        expect(result).to be false
      end
    end
  end

  describe '.migration_complete?' do
    let!(:user1) do
      TestUser.create!(
        name: 'Test User 1',
        email: 'user1@example.com',
        crypted_password: nil,
        password_digest: nil
      )
    end

    let!(:user2) do
      TestUser.create!(
        name: 'Test User 2',
        email: 'user2@example.com',
        crypted_password: nil,
        password_digest: nil
      )
    end

    context 'when all users have been migrated' do
      before do
        user1.update!(
          crypted_password: 'hash1',
          password_digest: 'hash1'
        )
        user2.update!(
          crypted_password: 'hash2',
          password_digest: 'hash2'
        )
      end

      it 'returns true' do
        result = described_class.migration_complete?(TestUser)

        expect(result).to be true
      end
    end

    context 'when some users have not been migrated' do
      before do
        user1.update!(
          crypted_password: 'hash1',
          password_digest: nil
        ) # Not migrated
        user2.update!(
          crypted_password: 'hash2',
          password_digest: 'hash2'
        ) # Migrated
      end

      it 'returns false' do
        result = described_class.migration_complete?(TestUser)

        expect(result).to be false
      end
    end

    context 'when users have no crypted_password' do
      before do
        user1.update!(
          crypted_password: nil,
          password_digest: nil
        )
        user2.update!(
          crypted_password: nil,
          password_digest: 'some_hash'
        )
      end

      it 'returns true' do
        # No users have crypted_password without password_digest
        result = described_class.migration_complete?(TestUser)

        expect(result).to be true
      end
    end

    context 'when no users exist' do
      before do
        TestUser.delete_all
      end

      it 'returns true' do
        result = described_class.migration_complete?(TestUser)

        expect(result).to be true
      end
    end

    context 'when mixed migration states' do
      before do
        user1.update!(
          crypted_password: 'hash1',
          password_digest: 'hash1'
        ) # Migrated
        user2.update!(
          crypted_password: 'hash2',
          password_digest: nil
        ) # Not migrated
      end

      it 'returns false' do
        result = described_class.migration_complete?(TestUser)

        expect(result).to be false
      end

      it 'identifies the exact number of unmigrated records' do
        unmigrated_count = TestUser.where(password_digest: nil)
                                   .where.not(crypted_password: nil)
                                   .count

        expect(unmigrated_count).to eq(1)
      end
    end
  end
end
