# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authentication::PasswordProvider do
  subject(:provider) { described_class.new }

  let(:email) { 'operator@example.com' }
  let(:password) { 'SecurePassword123!' }
  let(:operator) { create(:operator, email: email, password: password, password_confirmation: password) }

  describe '#authenticate' do
    context 'when authentication is successful' do
      before do
        operator # Create operator before test
      end

      it 'returns success result' do
        result = provider.authenticate(email: email, password: password)
        expect(result.success?).to be true
      end

      it 'returns the authenticated operator' do
        result = provider.authenticate(email: email, password: password)
        expect(result.user).to eq(operator)
      end

      it 'resets failed login counter' do
        operator.update_columns(failed_logins_count: 3)

        provider.authenticate(email: email, password: password)

        expect(operator.reload.failed_logins_count).to eq(0)
      end

      it 'handles case-insensitive email' do
        result = provider.authenticate(email: email.upcase, password: password)
        expect(result.success?).to be true
        expect(result.user).to eq(operator)
      end
    end

    context 'when operator is not found' do
      it 'returns failed result with :user_not_found reason' do
        result = provider.authenticate(email: 'nonexistent@example.com', password: password)

        expect(result.failed?).to be true
        expect(result.reason).to eq(:user_not_found)
      end

      it 'does not return user' do
        result = provider.authenticate(email: 'nonexistent@example.com', password: password)
        expect(result.user).to be_nil
      end
    end

    context 'when account is locked' do
      before do
        operator.lock_account!
      end

      it 'returns failed result with :account_locked reason' do
        result = provider.authenticate(email: email, password: password)

        expect(result.failed?).to be true
        expect(result.reason).to eq(:account_locked)
      end

      it 'returns the locked operator' do
        result = provider.authenticate(email: email, password: password)
        expect(result.user).to eq(operator)
      end

      it 'does not attempt password verification' do
        allow(operator).to receive(:authenticate).and_call_original

        provider.authenticate(email: email, password: password)

        expect(operator).not_to have_received(:authenticate)
      end

      it 'does not increment failed logins counter' do
        initial_count = operator.failed_logins_count

        provider.authenticate(email: email, password: password)

        expect(operator.reload.failed_logins_count).to eq(initial_count)
      end
    end

    context 'when password is invalid' do
      before do
        operator # Create operator before test
      end

      it 'returns failed result with :invalid_credentials reason' do
        result = provider.authenticate(email: email, password: 'wrong_password')

        expect(result.failed?).to be true
        expect(result.reason).to eq(:invalid_credentials)
      end

      it 'returns the operator for tracking purposes' do
        result = provider.authenticate(email: email, password: 'wrong_password')
        expect(result.user).to eq(operator)
      end

      it 'increments failed logins counter' do
        initial_count = operator.failed_logins_count

        provider.authenticate(email: email, password: 'wrong_password')

        expect(operator.reload.failed_logins_count).to eq(initial_count + 1)
      end

      it 'locks account after reaching retry limit' do
        # Set failed logins to one less than limit
        operator.update_columns(failed_logins_count: operator.lock_retry_limit - 1)

        provider.authenticate(email: email, password: 'wrong_password')

        expect(operator.reload.locked?).to be true
      end
    end

    context 'with brute force protection integration' do
      before do
        operator # Create operator before test
      end

      it 'tracks multiple failed attempts' do
        3.times do
          provider.authenticate(email: email, password: 'wrong_password')
        end

        expect(operator.reload.failed_logins_count).to eq(3)
      end

      it 'locks account after exceeding retry limit' do
        # Fail authentication lock_retry_limit times
        operator.lock_retry_limit.times do
          provider.authenticate(email: email, password: 'wrong_password')
        end

        expect(operator.reload.locked?).to be true
      end

      it 'resets counter on successful authentication after failures' do
        # Fail twice
        2.times { provider.authenticate(email: email, password: 'wrong_password') }

        # Then succeed
        provider.authenticate(email: email, password: password)

        expect(operator.reload.failed_logins_count).to eq(0)
      end

      it 'sets lock expiration time when locking' do
        operator.lock_retry_limit.times do
          provider.authenticate(email: email, password: 'wrong_password')
        end

        expect(operator.reload.lock_expires_at).to be_present
        expect(operator.reload.lock_expires_at).to be > Time.current
      end

      it 'generates unlock token when locking' do
        operator.lock_retry_limit.times do
          provider.authenticate(email: email, password: 'wrong_password')
        end

        expect(operator.reload.unlock_token).to be_present
      end
    end

    context 'with edge cases' do
      before do
        operator # Create operator before test
      end

      it 'handles empty email' do
        result = provider.authenticate(email: '', password: password)

        expect(result.failed?).to be true
        expect(result.reason).to eq(:user_not_found)
      end

      it 'handles nil email' do
        result = provider.authenticate(email: nil, password: password)

        expect(result.failed?).to be true
        expect(result.reason).to eq(:user_not_found)
      end

      it 'handles empty password' do
        result = provider.authenticate(email: email, password: '')

        expect(result.failed?).to be true
        expect(result.reason).to eq(:invalid_credentials)
      end

      it 'handles email with leading/trailing spaces' do
        result = provider.authenticate(email: "  #{email}  ", password: password)

        expect(result.success?).to be true
        expect(result.user).to eq(operator)
      end
    end
  end

  describe '#supports?' do
    it 'returns true for :password credential type' do
      expect(provider.supports?(:password)).to be true
    end

    it 'returns false for :oauth credential type' do
      expect(provider.supports?(:oauth)).to be false
    end

    it 'returns false for :saml credential type' do
      expect(provider.supports?(:saml)).to be false
    end

    it 'returns false for :mfa credential type' do
      expect(provider.supports?(:mfa)).to be false
    end

    it 'returns false for :totp credential type' do
      expect(provider.supports?(:totp)).to be false
    end

    it 'returns false for any unsupported credential type' do
      expect(provider.supports?(:webauthn)).to be false
      expect(provider.supports?(:fingerprint)).to be false
    end
  end

  describe 'inheritance' do
    it 'inherits from Authentication::Provider' do
      expect(described_class).to be < Authentication::Provider
    end

    it 'implements required authenticate method' do
      expect(provider).to respond_to(:authenticate)
    end

    it 'implements required supports? method' do
      expect(provider).to respond_to(:supports?)
    end
  end

  describe 'return value contracts' do
    let(:operator) { create(:operator, email: email, password: password, password_confirmation: password) }

    it 'always returns an AuthResult object' do
      result = provider.authenticate(email: email, password: password)
      expect(result).to be_an(AuthResult)
    end

    it 'returns immutable results' do
      result = provider.authenticate(email: email, password: password)
      expect(result).to be_frozen
    end

    it 'supports? returns a boolean' do
      result = provider.supports?(:password)
      expect(result).to be_in([true, false])
    end
  end
end
