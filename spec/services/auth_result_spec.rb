# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthResult do
  let(:user) { instance_double('User', id: 1, email: 'test@example.com') }

  describe '.success' do
    subject(:result) { described_class.success(user: user) }

    it 'creates a result with success status' do
      expect(result.status).to eq(:success)
    end

    it 'stores the user' do
      expect(result.user).to eq(user)
    end

    it 'has no reason' do
      expect(result.reason).to be_nil
    end

    it 'is immutable' do
      expect(result).to be_frozen
    end
  end

  describe '.failed' do
    subject(:result) { described_class.failed('invalid_password', user: user) }

    it 'creates a result with failed status' do
      expect(result.status).to eq(:failed)
    end

    it 'stores the failure reason' do
      expect(result.reason).to eq('invalid_password')
    end

    it 'stores the user' do
      expect(result.user).to eq(user)
    end

    it 'is immutable' do
      expect(result).to be_frozen
    end

    context 'without user' do
      subject(:result) { described_class.failed('account_locked') }

      it 'creates a result without user' do
        expect(result.user).to be_nil
      end

      it 'stores the failure reason' do
        expect(result.reason).to eq('account_locked')
      end
    end
  end

  describe '.pending_mfa' do
    subject(:result) { described_class.pending_mfa(user: user) }

    it 'creates a result with pending_mfa status' do
      expect(result.status).to eq(:pending_mfa)
    end

    it 'stores the user' do
      expect(result.user).to eq(user)
    end

    it 'has no reason' do
      expect(result.reason).to be_nil
    end

    it 'is immutable' do
      expect(result).to be_frozen
    end
  end

  describe '#success?' do
    it 'returns true for success status' do
      result = described_class.success(user: user)
      expect(result.success?).to be true
    end

    it 'returns false for failed status' do
      result = described_class.failed('invalid_password', user: user)
      expect(result.success?).to be false
    end

    it 'returns false for pending_mfa status' do
      result = described_class.pending_mfa(user: user)
      expect(result.success?).to be false
    end
  end

  describe '#failed?' do
    it 'returns false for success status' do
      result = described_class.success(user: user)
      expect(result.failed?).to be false
    end

    it 'returns true for failed status' do
      result = described_class.failed('invalid_password', user: user)
      expect(result.failed?).to be true
    end

    it 'returns false for pending_mfa status' do
      result = described_class.pending_mfa(user: user)
      expect(result.failed?).to be false
    end
  end

  describe '#pending_mfa?' do
    it 'returns false for success status' do
      result = described_class.success(user: user)
      expect(result.pending_mfa?).to be false
    end

    it 'returns false for failed status' do
      result = described_class.failed('invalid_password', user: user)
      expect(result.pending_mfa?).to be false
    end

    it 'returns true for pending_mfa status' do
      result = described_class.pending_mfa(user: user)
      expect(result.pending_mfa?).to be true
    end
  end

  describe 'immutability' do
    it 'prevents modification of status' do
      result = described_class.success(user: user)
      expect { result.instance_variable_set(:@status, :failed) }
        .to raise_error(FrozenError)
    end

    it 'prevents modification of user' do
      result = described_class.success(user: user)
      expect { result.instance_variable_set(:@user, nil) }
        .to raise_error(FrozenError)
    end

    it 'prevents modification of reason' do
      result = described_class.failed('test_reason', user: user)
      expect { result.instance_variable_set(:@reason, 'new_reason') }
        .to raise_error(FrozenError)
    end
  end

  describe 'factory method usage patterns' do
    it 'supports success workflow' do
      result = described_class.success(user: user)

      expect(result.success?).to be true
      expect(result.user).to eq(user)
    end

    it 'supports failed workflow with user tracking' do
      result = described_class.failed('invalid_password', user: user)

      expect(result.failed?).to be true
      expect(result.reason).to eq('invalid_password')
      expect(result.user).to eq(user)
    end

    it 'supports failed workflow without user' do
      result = described_class.failed('account_locked')

      expect(result.failed?).to be true
      expect(result.reason).to eq('account_locked')
      expect(result.user).to be_nil
    end

    it 'supports MFA workflow' do
      result = described_class.pending_mfa(user: user)

      expect(result.pending_mfa?).to be true
      expect(result.user).to eq(user)
    end
  end

  describe 'multiple status checks' do
    it 'ensures only one status is true at a time for success' do
      result = described_class.success(user: user)

      expect(result.success?).to be true
      expect(result.failed?).to be false
      expect(result.pending_mfa?).to be false
    end

    it 'ensures only one status is true at a time for failed' do
      result = described_class.failed('invalid_password', user: user)

      expect(result.success?).to be false
      expect(result.failed?).to be true
      expect(result.pending_mfa?).to be false
    end

    it 'ensures only one status is true at a time for pending_mfa' do
      result = described_class.pending_mfa(user: user)

      expect(result.success?).to be false
      expect(result.failed?).to be false
      expect(result.pending_mfa?).to be true
    end
  end
end
