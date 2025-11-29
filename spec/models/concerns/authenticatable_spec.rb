# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authenticatable, type: :model do
  # Create a mock Operator class for testing (reusing existing Operator model)
  let(:operator_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'operators'
      include Authenticatable
      authenticates_with model: Operator, path_prefix: 'operator'
    end
  end

  # Create a mock Admin class for testing multi-model support
  let(:admin_class) do
    Class.new do
      include ActiveModel::Model
      include Authenticatable
      authenticates_with model: self, path_prefix: 'admin'
    end
  end

  # Create a mock Customer class without path_prefix
  let(:customer_class) do
    Class.new do
      include ActiveModel::Model
      include Authenticatable
      authenticates_with model: self
    end
  end

  describe '.authenticates_with' do
    context 'when configured with model and path_prefix' do
      it 'sets the authenticated_model' do
        expect(operator_class.authenticated_model).to eq(Operator)
      end

      it 'sets the path_prefix' do
        expect(operator_class.path_prefix).to eq('operator')
      end
    end

    context 'when configured with different path_prefix' do
      it 'sets the authenticated_model for Admin' do
        expect(admin_class.authenticated_model).to eq(admin_class)
      end

      it 'sets the path_prefix for Admin' do
        expect(admin_class.path_prefix).to eq('admin')
      end
    end

    context 'when configured without path_prefix' do
      it 'sets the authenticated_model' do
        expect(customer_class.authenticated_model).to eq(customer_class)
      end

      it 'sets path_prefix to nil' do
        expect(customer_class.path_prefix).to be_nil
      end
    end
  end

  describe '.authenticated_model' do
    it 'returns the configured model for Operator' do
      expect(operator_class.authenticated_model).to eq(Operator)
    end

    it 'returns the configured model for Admin' do
      expect(admin_class.authenticated_model).to eq(admin_class)
    end

    it 'returns the configured model for Customer' do
      expect(customer_class.authenticated_model).to eq(customer_class)
    end
  end

  describe '.path_prefix' do
    it 'returns the configured path_prefix for Operator' do
      expect(operator_class.path_prefix).to eq('operator')
    end

    it 'returns the configured path_prefix for Admin' do
      expect(admin_class.path_prefix).to eq('admin')
    end

    it 'returns nil for Customer without path_prefix' do
      expect(customer_class.path_prefix).to be_nil
    end
  end

  describe 'multi-model support' do
    it 'allows multiple models to use the concern independently' do
      # Operator configuration
      expect(operator_class.authenticated_model).to eq(Operator)
      expect(operator_class.path_prefix).to eq('operator')

      # Admin configuration
      expect(admin_class.authenticated_model).to eq(admin_class)
      expect(admin_class.path_prefix).to eq('admin')

      # Verify they don't interfere with each other
      expect(operator_class.path_prefix).not_to eq(admin_class.path_prefix)
    end

    it 'supports models with and without path_prefix' do
      # With path_prefix
      expect(operator_class.path_prefix).to eq('operator')

      # Without path_prefix
      expect(customer_class.path_prefix).to be_nil
    end
  end

  describe 'integration with Operator model' do
    context 'when included in Operator model' do
      before do
        # Temporarily include the concern in the existing Operator model
        unless Operator.included_modules.include?(described_class)
          Operator.include(described_class)
          Operator.authenticates_with model: Operator, path_prefix: 'operator'
        end
      end

      it 'provides authenticates_with configuration' do
        expect(Operator).to respond_to(:authenticates_with)
      end

      it 'provides authenticated_model reader' do
        expect(Operator).to respond_to(:authenticated_model)
      end

      it 'provides path_prefix reader' do
        expect(Operator).to respond_to(:path_prefix)
      end

      it 'allows configuration to be accessed' do
        expect(Operator.authenticated_model).to eq(Operator)
        expect(Operator.path_prefix).to eq('operator')
      end
    end
  end

  describe 'future extensibility' do
    it 'can be extended with instance methods' do
      # This test verifies that the concern can be extended with instance methods
      # in future iterations without breaking existing functionality
      extended_class = Class.new do
        include ActiveModel::Model
        include Authenticatable

        authenticates_with model: self, path_prefix: 'extended'

        # Example of future instance method
        def login_path
          "/#{self.class.path_prefix}/login"
        end
      end

      instance = extended_class.new
      expect(instance).to respond_to(:login_path)
      expect(instance.login_path).to eq('/extended/login')
    end
  end
end
