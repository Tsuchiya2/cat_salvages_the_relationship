# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthenticationService do
  let(:user) { instance_double(Operator, id: 1, email: 'test@example.com') }
  let(:ip_address) { '192.168.1.1' }
  let(:request_id) { 'req-12345' }

  before do
    # Setup request correlation
    RequestStore.store[:request_id] = request_id
    allow(Rails.logger).to receive(:info)
  end

  describe '.authenticate with password provider' do
    let(:password_provider) { instance_double(Authentication::PasswordProvider) }

    before do
      allow(Authentication::PasswordProvider).to receive(:new).and_return(password_provider)
    end

    context 'when authentication succeeds' do
      let(:success_result) { AuthResult.success(user: user) }

      before do
        allow(password_provider).to receive(:authenticate)
          .with(email: 'test@example.com', password: 'secret123')
          .and_return(success_result)
      end

      it 'returns successful AuthResult' do
        result = described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'secret123',
          ip_address: ip_address
        )

        expect(result).to eq(success_result)
        expect(result.success?).to be true
        expect(result.user).to eq(user)
      end

      it 'routes credentials to password provider' do
        described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'secret123'
        )

        expect(password_provider).to have_received(:authenticate)
          .with(email: 'test@example.com', password: 'secret123')
      end

      it 'logs authentication attempt with success status' do
        described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'secret123',
          ip_address: ip_address
        )

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: 'authentication_attempt',
            provider: :password,
            result: :success,
            reason: nil,
            ip: ip_address,
            request_id: request_id
          )
        )
      end

      it 'includes timestamp in log' do
        freeze_time do
          described_class.authenticate(
            :password,
            email: 'test@example.com',
            password: 'secret123'
          )

          expect(Rails.logger).to have_received(:info).with(
            hash_including(timestamp: Time.current.iso8601)
          )
        end
      end
    end

    context 'when authentication fails' do
      let(:failed_result) { AuthResult.failed('invalid_password', user: user) }

      before do
        allow(password_provider).to receive(:authenticate)
          .with(email: 'test@example.com', password: 'wrong')
          .and_return(failed_result)
      end

      it 'returns failed AuthResult' do
        result = described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'wrong'
        )

        expect(result).to eq(failed_result)
        expect(result.failed?).to be true
        expect(result.reason).to eq('invalid_password')
      end

      it 'logs authentication attempt with failed status and reason' do
        described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'wrong',
          ip_address: ip_address
        )

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: 'authentication_attempt',
            provider: :password,
            result: :failed,
            reason: 'invalid_password',
            ip: ip_address
          )
        )
      end
    end

    context 'when MFA is pending' do
      let(:pending_result) { AuthResult.pending_mfa(user: user) }

      before do
        allow(password_provider).to receive(:authenticate)
          .with(email: 'test@example.com', password: 'secret123')
          .and_return(pending_result)
      end

      it 'returns pending_mfa AuthResult' do
        result = described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'secret123'
        )

        expect(result).to eq(pending_result)
        expect(result.pending_mfa?).to be true
      end

      it 'logs authentication attempt with pending_mfa status' do
        described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'secret123',
          ip_address: ip_address
        )

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            event: 'authentication_attempt',
            provider: :password,
            result: :pending_mfa,
            ip: ip_address
          )
        )
      end
    end

    context 'without ip_address' do
      it 'logs with nil ip address' do
        success_result = AuthResult.success(user: user)
        allow(password_provider).to receive(:authenticate).and_return(success_result)

        described_class.authenticate(:password, email: 'test@example.com', password: 'secret123')

        expect(Rails.logger).to have_received(:info).with(
          hash_including(ip: nil)
        )
      end
    end

    context 'with missing request_id' do
      before do
        RequestStore.store[:request_id] = nil
      end

      it 'logs with nil request_id' do
        success_result = AuthResult.success(user: user)
        allow(password_provider).to receive(:authenticate).and_return(success_result)

        described_class.authenticate(:password, email: 'test@example.com', password: 'secret123')

        expect(Rails.logger).to have_received(:info).with(
          hash_including(request_id: nil)
        )
      end
    end

    context 'with unknown provider type' do
      it 'raises ArgumentError' do
        expect do
          described_class.authenticate(:unknown_provider, email: 'test@example.com')
        end.to raise_error(ArgumentError, 'Unknown provider type: unknown_provider')
      end

      it 'does not log authentication attempt for unknown provider' do
        begin
          described_class.authenticate(:invalid_type, credentials: {})
        rescue ArgumentError
          # Expected error
        end

        expect(Rails.logger).not_to have_received(:info)
      end
    end

    context 'provider routing' do
      it 'creates new PasswordProvider instance for :password type' do
        password_provider = instance_double(Authentication::PasswordProvider)
        allow(Authentication::PasswordProvider).to receive(:new).and_return(password_provider)
        allow(password_provider).to receive(:authenticate).and_return(AuthResult.success(user: user))

        described_class.authenticate(:password, email: 'test@example.com', password: 'secret123')

        expect(Authentication::PasswordProvider).to have_received(:new)
      end

      it 'passes all credentials to provider' do
        password_provider = instance_double(Authentication::PasswordProvider)
        allow(Authentication::PasswordProvider).to receive(:new).and_return(password_provider)
        allow(password_provider).to receive(:authenticate).and_return(AuthResult.success(user: user))

        described_class.authenticate(
          :password,
          email: 'user@example.com',
          password: 'pass123',
          ip_address: '10.0.0.1'
        )

        expect(password_provider).to have_received(:authenticate)
          .with(email: 'user@example.com', password: 'pass123')
      end
    end

    context 'request correlation' do
      it 'includes request_id from RequestStore in log' do
        password_provider = instance_double(Authentication::PasswordProvider)
        allow(Authentication::PasswordProvider).to receive(:new).and_return(password_provider)
        allow(password_provider).to receive(:authenticate).and_return(AuthResult.success(user: user))

        custom_request_id = 'custom-req-999'
        RequestStore.store[:request_id] = custom_request_id

        described_class.authenticate(:password, email: 'test@example.com', password: 'secret123')

        expect(Rails.logger).to have_received(:info).with(
          hash_including(request_id: custom_request_id)
        )
      end
    end
  end

  describe 'structured logging format' do
    let(:password_provider) { instance_double(Authentication::PasswordProvider) }
    let(:success_result) { AuthResult.success(user: user) }

    before do
      allow(Authentication::PasswordProvider).to receive(:new).and_return(password_provider)
      allow(password_provider).to receive(:authenticate).and_return(success_result)
    end

    it 'includes all required observability fields' do
      freeze_time do
        described_class.authenticate(
          :password,
          email: 'test@example.com',
          password: 'secret123',
          ip_address: ip_address
        )

        expect(Rails.logger).to have_received(:info).with(
          event: 'authentication_attempt',
          provider: :password,
          result: :success,
          reason: nil,
          ip: ip_address,
          request_id: request_id,
          timestamp: Time.current.iso8601
        )
      end
    end

    it 'uses ISO8601 timestamp format' do
      freeze_time do
        described_class.authenticate(:password, email: 'test@example.com', password: 'secret123')

        expect(Rails.logger).to have_received(:info).with(
          hash_including(timestamp: Time.current.iso8601)
        )
      end
    end
  end

  describe 'extensibility' do
    it 'supports future provider types through provider_for method' do
      # This test documents that new providers can be added by:
      # 1. Creating new provider class (e.g., Authentication::OAuthProvider)
      # 2. Adding new case to provider_for method
      # 3. No changes needed to authenticate method

      expect do
        described_class.authenticate(:oauth, token: 'oauth_token')
      end.to raise_error(ArgumentError, /oauth/)
    end
  end
end
