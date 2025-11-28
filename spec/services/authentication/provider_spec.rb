# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authentication::Provider do
  # Concrete implementation for testing abstract class
  class TestProvider < Authentication::Provider
    attr_accessor :should_authenticate, :supported_types, :test_user

    def initialize(test_user: nil)
      @should_authenticate = false
      @supported_types = []
      @test_user = test_user
    end

    def authenticate(credentials)
      super if !should_authenticate

      # Use the test_user passed during initialization
      user = test_user || Object.new.tap do |u|
        u.define_singleton_method(:id) { 1 }
        u.define_singleton_method(:email) { credentials[:email] }
      end
      AuthResult.success(user: user)
    end

    def supports?(credential_type)
      super if supported_types.empty?

      supported_types.include?(credential_type)
    end
  end

  describe 'abstract interface' do
    subject(:provider) { described_class.new }

    describe '#authenticate' do
      it 'raises NotImplementedError when not overridden' do
        expect { provider.authenticate(email: 'test@example.com', password: 'secret') }
          .to raise_error(NotImplementedError, /must implement #authenticate/)
      end

      it 'includes the class name in error message' do
        expect { provider.authenticate({}) }
          .to raise_error(NotImplementedError, /Authentication::Provider/)
      end
    end

    describe '#supports?' do
      it 'raises NotImplementedError when not overridden' do
        expect { provider.supports?(:password) }
          .to raise_error(NotImplementedError, /must implement #supports\?/)
      end

      it 'includes the class name in error message' do
        expect { provider.supports?(:oauth) }
          .to raise_error(NotImplementedError, /Authentication::Provider/)
      end
    end
  end

  describe 'subclass implementation' do
    subject(:provider) { TestProvider.new }

    describe '#authenticate' do
      context 'when implemented by subclass' do
        before do
          provider.should_authenticate = true
        end

        it 'does not raise NotImplementedError' do
          expect { provider.authenticate(email: 'test@example.com', password: 'secret') }
            .not_to raise_error
        end

        it 'returns an AuthResult' do
          result = provider.authenticate(email: 'test@example.com', password: 'secret')
          expect(result).to be_a(AuthResult)
        end

        it 'can return successful authentication' do
          result = provider.authenticate(email: 'test@example.com', password: 'secret')
          expect(result.success?).to be true
        end

        it 'passes credentials to implementation' do
          credentials = { email: 'user@example.com', password: 'pass123' }
          result = provider.authenticate(credentials)
          expect(result.user.email).to eq('user@example.com')
        end
      end

      context 'when not implemented by subclass' do
        before do
          provider.should_authenticate = false
        end

        it 'raises NotImplementedError' do
          expect { provider.authenticate({}) }
            .to raise_error(NotImplementedError, /TestProvider/)
        end
      end
    end

    describe '#supports?' do
      context 'when implemented by subclass' do
        before do
          provider.supported_types = %i[password oauth]
        end

        it 'does not raise NotImplementedError' do
          expect { provider.supports?(:password) }
            .not_to raise_error
        end

        it 'returns true for supported credential types' do
          expect(provider.supports?(:password)).to be true
          expect(provider.supports?(:oauth)).to be true
        end

        it 'returns false for unsupported credential types' do
          expect(provider.supports?(:saml)).to be false
          expect(provider.supports?(:mfa)).to be false
        end

        it 'accepts various credential type symbols' do
          provider.supported_types = %i[totp webauthn]
          expect(provider.supports?(:totp)).to be true
          expect(provider.supports?(:webauthn)).to be true
        end
      end

      context 'when not implemented by subclass' do
        before do
          provider.supported_types = []
        end

        it 'raises NotImplementedError' do
          expect { provider.supports?(:password) }
            .to raise_error(NotImplementedError, /TestProvider/)
        end
      end
    end
  end

  describe 'inheritance behavior' do
    it 'allows subclasses to be created' do
      expect { Class.new(described_class) }.not_to raise_error
    end

    it 'subclass inherits abstract interface' do
      subclass = Class.new(described_class)
      instance = subclass.new

      expect { instance.authenticate({}) }
        .to raise_error(NotImplementedError)
      expect { instance.supports?(:password) }
        .to raise_error(NotImplementedError)
    end

    it 'allows multiple subclasses with different implementations' do
      class PasswordProvider < Authentication::Provider
        def supports?(credential_type)
          credential_type == :password
        end
      end

      class OAuthProvider < Authentication::Provider
        def supports?(credential_type)
          credential_type == :oauth
        end
      end

      password_provider = PasswordProvider.new
      oauth_provider = OAuthProvider.new

      expect(password_provider.supports?(:password)).to be true
      expect(password_provider.supports?(:oauth)).to be false

      expect(oauth_provider.supports?(:oauth)).to be true
      expect(oauth_provider.supports?(:password)).to be false
    end
  end

  describe 'contract validation' do
    subject(:provider) { TestProvider.new }

    before do
      provider.should_authenticate = true
      provider.supported_types = %i[password]
    end

    it 'ensures authenticate method accepts credentials hash' do
      expect { provider.authenticate(email: 'test@example.com') }
        .not_to raise_error
    end

    it 'ensures supports? method accepts credential_type symbol' do
      expect { provider.supports?(:password) }
        .not_to raise_error
    end

    it 'ensures authenticate returns AuthResult object' do
      result = provider.authenticate(email: 'test@example.com', password: 'secret')
      expect(result).to be_a(AuthResult)
      expect(result).to respond_to(:success?)
      expect(result).to respond_to(:failed?)
      expect(result).to respond_to(:pending_mfa?)
    end

    it 'ensures supports? returns boolean' do
      result = provider.supports?(:password)
      expect(result).to be_in([true, false])
    end
  end

  describe 'usage patterns' do
    it 'supports polymorphic provider selection' do
      providers = [
        TestProvider.new.tap { |p| p.supported_types = [:password] },
        TestProvider.new.tap { |p| p.supported_types = [:oauth] },
        TestProvider.new.tap { |p| p.supported_types = %i[mfa totp] }
      ]

      password_provider = providers.find { |p| p.supports?(:password) }
      oauth_provider = providers.find { |p| p.supports?(:oauth) }
      mfa_provider = providers.find { |p| p.supports?(:mfa) }

      expect(password_provider).to be_a(TestProvider)
      expect(oauth_provider).to be_a(TestProvider)
      expect(mfa_provider).to be_a(TestProvider)
    end

    it 'supports credential type validation before authentication' do
      provider = TestProvider.new
      provider.supported_types = [:password]
      provider.should_authenticate = true

      credential_type = :password

      if provider.supports?(credential_type)
        result = provider.authenticate(email: 'test@example.com', password: 'secret')
        expect(result).to be_a(AuthResult)
      end
    end
  end
end
