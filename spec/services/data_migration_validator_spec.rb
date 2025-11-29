# frozen_string_literal: true

require 'rails_helper'

# NOTE: These tests are for the migration tool that was used to migrate from Sorcery to Rails 8 authentication.
# Since the migration is complete and crypted_password column has been removed, these tests are now skipped.
RSpec.describe DataMigrationValidator, skip: 'Migration complete - crypted_password column removed' do
  describe '.generate_checksum' do
    before do
      # Clean up any existing operators to prevent email uniqueness conflicts
      Operator.delete_all
    end

    let!(:operator1) do
      Operator.create!(
        name: 'Test User 1',
        email: 'test1@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        role: :operator
      )
    end

    let!(:operator2) do
      Operator.create!(
        name: 'Test User 2',
        email: 'test2@example.com',
        password: 'password456',
        password_confirmation: 'password456',
        role: :operator
      )
    end

    it 'generates checksums for all records' do
      checksums = described_class.generate_checksum(Operator)

      expect(checksums).to be_an(Array)
      expect(checksums.size).to eq(2)
    end

    it 'generates SHA256 checksums' do
      checksums = described_class.generate_checksum(Operator)

      expect(checksums).to all(match(/\A[a-f0-9]{64}\z/))
    end

    it 'generates consistent checksums for same data' do
      checksums1 = described_class.generate_checksum(Operator)
      checksums2 = described_class.generate_checksum(Operator)

      expect(checksums1).to eq(checksums2)
    end

    it 'generates different checksums when data changes' do
      checksums_before = described_class.generate_checksum(Operator)

      operator1.update!(crypted_password: 'new_password_hash')

      checksums_after = described_class.generate_checksum(Operator)

      expect(checksums_before).not_to eq(checksums_after)
    end
  end

  describe '.validate_migration' do
    let(:checksums1) { %w[abc123 def456 ghi789] }
    let(:checksums2) { %w[abc123 def456 ghi789] }

    context 'when checksums match' do
      it 'returns true' do
        result = described_class.validate_migration(checksums1, checksums2)

        expect(result).to be true
      end
    end

    context 'when records are lost' do
      let(:checksums_after) { %w[abc123 def456] }

      it 'raises error with missing count' do
        expect { described_class.validate_migration(checksums1, checksums_after) }
          .to raise_error(RuntimeError, 'Migration validation failed: 1 records lost')
      end
    end

    context 'when unexpected records are added' do
      let(:checksums_after) { %w[abc123 def456 ghi789 jkl012] }

      it 'raises error with added count' do
        expect { described_class.validate_migration(checksums1, checksums_after) }
          .to raise_error(RuntimeError, 'Migration validation failed: 1 unexpected records added')
      end
    end

    context 'when records are modified' do
      let(:checksums_after) { %w[abc123 def456 xyz999] }

      it 'raises error about modified records' do
        expect { described_class.validate_migration(checksums1, checksums_after) }
          .to raise_error(RuntimeError, /Migration validation failed: \d+ records modified or corrupted/)
      end
    end

    context 'when order changes but data is same' do
      let(:checksums_after) { %w[ghi789 abc123 def456] }

      it 'returns true' do
        result = described_class.validate_migration(checksums1, checksums_after)

        expect(result).to be true
      end
    end
  end

  describe '.verify_integrity' do
    before do
      # Clean up any existing operators to prevent email uniqueness conflicts
      Operator.delete_all
    end

    context 'when all records have valid authentication data' do
      let!(:operator) do
        Operator.create!(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :operator
        )
      end

      it 'returns valid result' do
        result = described_class.verify_integrity(Operator)

        expect(result[:valid]).to be true
        expect(result[:total_records]).to eq(1)
        expect(result[:issues]).to be_empty
      end
    end

    context 'when records have missing authentication data' do
      let!(:operator) do
        Operator.create!(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :operator
        )
      end

      before do
        operator.update!(crypted_password: nil, password_digest: nil)
      end

      it 'reports missing authentication data' do
        result = described_class.verify_integrity(Operator)

        expect(result[:valid]).to be false
        expect(result[:issues]).to include('1 records missing authentication data')
      end
    end

    context 'when records have duplicate authentication methods' do
      let!(:operator) do
        Operator.create!(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :operator
        )
      end

      before do
        # Simulate having both authentication methods
        operator.update!(
          crypted_password: 'old_password_hash',
          password_digest: operator.crypted_password
        )
      end

      it 'reports duplicate authentication methods' do
        result = described_class.verify_integrity(Operator)

        expect(result[:valid]).to be false
        expect(result[:issues]).to include('1 records have both crypted_password and password_digest')
      end
    end
  end

  describe '.validate_password_migration' do
    before do
      # Clean up any existing operators to prevent email uniqueness conflicts
      Operator.delete_all
    end

    context 'when all operators have password_digest' do
      let!(:operator) do
        Operator.create!(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :operator
        )
      end

      before do
        # Simulate fully migrated state (password_digest set, crypted_password cleared)
        operator.update!(
          password_digest: BCrypt::Password.create('password123'),
          crypted_password: nil
        )
      end

      it 'returns true' do
        result = described_class.validate_password_migration

        expect(result).to be true
      end
    end

    context 'when operators are missing password_digest' do
      let!(:operator) do
        Operator.create!(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :operator
        )
      end

      before do
        # Simulate old Sorcery format (crypted_password only)
        operator.update!(
          crypted_password: 'old_password_hash',
          password_digest: nil
        )
      end

      it 'raises error with missing count' do
        expect { described_class.validate_password_migration }
          .to raise_error(RuntimeError, 'Migration incomplete: 1 operators missing password_digest')
      end
    end

    context 'when operators only have password_digest' do
      let!(:operator) do
        Operator.create!(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          role: :operator
        )
      end

      before do
        # Simulate fully migrated state (password_digest only)
        operator.update!(crypted_password: nil)
      end

      it 'returns true' do
        result = described_class.validate_password_migration

        expect(result).to be true
      end
    end
  end
end
