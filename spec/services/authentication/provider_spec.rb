# frozen_string_literal: true

require 'rails_helper'

# Concrete implementation for testing abstract class (defined outside spec block)
class TestAuthProvider < Authentication::Provider
  attr_accessor :should_authenticate, :supported_types, :test_user

  def initialize(test_user: nil)
    @should_authenticate = false
    @supported_types = []
    @test_user = test_user
  end

  def authenticate(credentials)
    super unless should_authenticate

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

RSpec.describe Authentication::Provider do
  describe '#authenticate (abstract)' do
    subject(:provider) { described_class.new }

    it 'raises NotImplementedError when not overridden' do
      expect { provider.authenticate(email: 'test@example.com', password: 'secret') }
        .to raise_error(NotImplementedError, /must implement #authenticate/)
    end

    it 'includes the class name in error message' do
      expect { provider.authenticate({}) }
        .to raise_error(NotImplementedError, /Authentication::Provider/)
    end
  end

  describe '#supports? (abstract)' do
    subject(:provider) { described_class.new }

    it 'raises NotImplementedError when not overridden' do
      expect { provider.supports?(:password) }
        .to raise_error(NotImplementedError, /must implement #supports\?/)
    end

    it 'includes the class name in error message' do
      expect { provider.supports?(:oauth) }
        .to raise_error(NotImplementedError, /Authentication::Provider/)
    end
  end

  describe '#authenticate (implemented)' do
    subject(:provider) { TestAuthProvider.new }

    it 'does not raise NotImplementedError when implemented' do
      provider.should_authenticate = true
      expect { provider.authenticate(email: 'test@example.com', password: 'secret') }
        .not_to raise_error
    end

    it 'returns an AuthResult' do
      provider.should_authenticate = true
      result = provider.authenticate(email: 'test@example.com', password: 'secret')
      expect(result).to be_a(AuthResult)
    end

    it 'can return successful authentication' do
      provider.should_authenticate = true
      result = provider.authenticate(email: 'test@example.com', password: 'secret')
      expect(result.success?).to be true
    end

    it 'passes credentials to implementation' do
      provider.should_authenticate = true
      credentials = { email: 'user@example.com', password: 'pass123' }
      result = provider.authenticate(credentials)
      expect(result.user.email).to eq('user@example.com')
    end

    it 'raises NotImplementedError when not properly implemented' do
      provider.should_authenticate = false
      expect { provider.authenticate({}) }
        .to raise_error(NotImplementedError, /TestAuthProvider/)
    end
  end

  describe '#supports? (implemented)' do
    subject(:provider) { TestAuthProvider.new }

    it 'does not raise NotImplementedError when implemented' do
      provider.supported_types = %i[password oauth]
      expect { provider.supports?(:password) }.not_to raise_error
    end

    it 'returns true for supported credential types' do
      provider.supported_types = %i[password oauth]
      expect(provider.supports?(:password)).to be true
      expect(provider.supports?(:oauth)).to be true
    end

    it 'returns false for unsupported credential types' do
      provider.supported_types = %i[password oauth]
      expect(provider.supports?(:saml)).to be false
      expect(provider.supports?(:mfa)).to be false
    end

    it 'accepts various credential type symbols' do
      provider.supported_types = %i[totp webauthn]
      expect(provider.supports?(:totp)).to be true
      expect(provider.supports?(:webauthn)).to be true
    end

    it 'raises NotImplementedError when not properly implemented' do
      provider.supported_types = []
      expect { provider.supports?(:password) }
        .to raise_error(NotImplementedError, /TestAuthProvider/)
    end
  end

  describe 'inheritance behavior' do
    it 'allows subclasses to be created' do
      expect { Class.new(described_class) }.not_to raise_error
    end

    it 'subclass inherits abstract interface' do
      subclass = Class.new(described_class)
      instance = subclass.new

      expect { instance.authenticate({}) }.to raise_error(NotImplementedError)
      expect { instance.supports?(:password) }.to raise_error(NotImplementedError)
    end

    it 'allows multiple subclasses with different implementations' do
      password_provider_class = Class.new(described_class) do
        define_method(:supports?) { |type| type == :password }
      end
      oauth_provider_class = Class.new(described_class) do
        define_method(:supports?) { |type| type == :oauth }
      end

      password_provider = password_provider_class.new
      oauth_provider = oauth_provider_class.new

      expect(password_provider.supports?(:password)).to be true
      expect(password_provider.supports?(:oauth)).to be false
      expect(oauth_provider.supports?(:oauth)).to be true
      expect(oauth_provider.supports?(:password)).to be false
    end
  end

  describe 'contract validation' do
    subject(:provider) { TestAuthProvider.new }

    before do
      provider.should_authenticate = true
      provider.supported_types = %i[password]
    end

    it 'ensures authenticate method accepts credentials hash' do
      expect { provider.authenticate(email: 'test@example.com') }.not_to raise_error
    end

    it 'ensures supports? method accepts credential_type symbol' do
      expect { provider.supports?(:password) }.not_to raise_error
    end

    it 'ensures authenticate returns AuthResult object' do
      result = provider.authenticate(email: 'test@example.com', password: 'secret')
      expect(result).to be_a(AuthResult)
      expect(result).to respond_to(:success?, :failed?, :pending_mfa?)
    end

    it 'ensures supports? returns boolean' do
      result = provider.supports?(:password)
      expect(result).to be_in([true, false])
    end
  end

  describe 'usage patterns' do
    it 'supports polymorphic provider selection' do
      providers = [
        TestAuthProvider.new.tap { |p| p.supported_types = [:password] },
        TestAuthProvider.new.tap { |p| p.supported_types = [:oauth] },
        TestAuthProvider.new.tap { |p| p.supported_types = %i[mfa totp] }
      ]

      password_provider = providers.find { |p| p.supports?(:password) }
      oauth_provider = providers.find { |p| p.supports?(:oauth) }
      mfa_provider = providers.find { |p| p.supports?(:mfa) }

      expect(password_provider).to be_a(TestAuthProvider)
      expect(oauth_provider).to be_a(TestAuthProvider)
      expect(mfa_provider).to be_a(TestAuthProvider)
    end

    it 'supports credential type validation before authentication' do
      provider = TestAuthProvider.new
      provider.supported_types = [:password]
      provider.should_authenticate = true

      if provider.supports?(:password)
        result = provider.authenticate(email: 'test@example.com', password: 'secret')
        expect(result).to be_a(AuthResult)
      end
    end
  end
end
