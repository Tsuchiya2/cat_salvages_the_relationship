# frozen_string_literal: true

require 'rails_helper'

# Test controller to include the Authentication concern
class TestAuthenticationController < ApplicationController
  include Authentication

  # Test actions
  def public_action
    render plain: 'public'
  end

  def protected_action
    render plain: 'protected'
  end

  def custom_not_authenticated_action
    render plain: 'custom'
  end
end

RSpec.describe Authentication, type: :controller do
  controller(TestAuthenticationController) do
    before_action :require_authentication, only: [:protected_action]

    def public_action
      render plain: 'public'
    end

    def protected_action
      render plain: "protected for #{current_operator.email}"
    end

    def custom_not_authenticated_action
      render plain: 'custom'
    end
  end

  let(:operator) { create(:operator, password: 'Password123', password_confirmation: 'Password123') }
  let(:request_ip) { '192.168.1.1' }
  let(:auth_result_success) { AuthResult.success(user: operator) }
  let(:auth_result_failed) { AuthResult.failed(:invalid_password) }
  let(:auth_result_locked) { AuthResult.failed(:account_locked, user: operator) }

  before do
    routes.draw do
      get 'public_action' => 'test_authentication#public_action'
      get 'protected_action' => 'test_authentication#protected_action'
      get 'custom_not_authenticated_action' => 'test_authentication#custom_not_authenticated_action'
    end

    allow(controller.request).to receive(:remote_ip).and_return(request_ip)
  end

  describe '#authenticate_operator' do
    before do
      allow(AuthenticationService).to receive(:authenticate).and_return(auth_result_success)
    end

    context 'when authentication is successful' do
      it 'returns the authenticated operator' do
        result = controller.authenticate_operator('test@example.com', 'password123')
        expect(result).to eq(operator)
      end

      it 'calls AuthenticationService with correct parameters' do
        expect(AuthenticationService).to receive(:authenticate).with(
          :password,
          email: 'test@example.com',
          password: 'password123',
          ip_address: request_ip
        )
        controller.authenticate_operator('test@example.com', 'password123')
      end
    end

    context 'when authentication fails' do
      before do
        allow(AuthenticationService).to receive(:authenticate).and_return(auth_result_failed)
      end

      it 'returns nil' do
        result = controller.authenticate_operator('test@example.com', 'wrong_password')
        expect(result).to be_nil
      end
    end

    context 'when account is locked' do
      before do
        allow(AuthenticationService).to receive(:authenticate).and_return(auth_result_locked)
        allow(operator).to receive(:mail_notice)
      end

      it 'returns nil' do
        result = controller.authenticate_operator('test@example.com', 'password123')
        expect(result).to be_nil
      end

      it 'sends notification email' do
        expect(operator).to receive(:mail_notice).with(request_ip)
        controller.authenticate_operator('test@example.com', 'password123')
      end
    end

    context 'when account is locked and user is nil' do
      let(:auth_result_locked_no_user) { AuthResult.failed(:account_locked) }

      before do
        allow(AuthenticationService).to receive(:authenticate)
          .and_return(auth_result_locked_no_user)
      end

      it 'does not raise error' do
        expect do
          controller.authenticate_operator('test@example.com', 'password123')
        end.not_to raise_error
      end
    end
  end

  describe '#login' do
    it 'sets operator_id in session' do
      controller.login(operator)
      expect(controller.session[:operator_id]).to eq(operator.id)
    end

    it 'sets @current_operator instance variable' do
      controller.login(operator)
      expect(controller.current_operator).to eq(operator)
    end

    it 'resets session to prevent session fixation' do
      controller.session[:some_key] = 'some_value'
      controller.login(operator)
      expect(controller.session[:some_key]).to be_nil
    end

    it 'returns the operator' do
      result = controller.login(operator)
      expect(result).to eq(operator)
    end
  end

  describe '#logout' do
    before do
      controller.login(operator)
    end

    it 'resets session' do
      controller.logout
      expect(controller.session[:operator_id]).to be_nil
    end

    it 'clears @current_operator instance variable' do
      controller.logout
      expect(controller.current_operator).to be_nil
    end

    it 'returns nil' do
      result = controller.logout
      expect(result).to be_nil
    end
  end

  describe '#current_operator' do
    context 'when operator is logged in' do
      before do
        controller.session[:operator_id] = operator.id
        controller.send(:set_current_operator)
      end

      it 'returns the current operator' do
        expect(controller.current_operator).to eq(operator)
      end
    end

    context 'when operator is not logged in' do
      it 'returns nil' do
        expect(controller.current_operator).to be_nil
      end
    end
  end

  describe '#operator_signed_in?' do
    context 'when operator is logged in' do
      before do
        controller.session[:operator_id] = operator.id
        controller.send(:set_current_operator)
      end

      it 'returns true' do
        expect(controller.operator_signed_in?).to be true
      end
    end

    context 'when operator is not logged in' do
      it 'returns false' do
        expect(controller.operator_signed_in?).to be false
      end
    end
  end

  describe '#require_authentication' do
    context 'when operator is logged in' do
      before do
        controller.session[:operator_id] = operator.id
        controller.send(:set_current_operator)
      end

      it 'allows access to protected action' do
        get :protected_action
        expect(response).to have_http_status(:success)
        expect(response.body).to eq("protected for #{operator.email}")
      end
    end

    context 'when operator is not logged in' do
      it 'redirects to login page' do
        get :protected_action
        expect(response).to redirect_to(operator_cat_in_path)
      end

      it 'sets alert message' do
        get :protected_action
        expect(flash[:alert]).to eq('セッションが切れました。再度ログインしてください。')
      end
    end
  end

  describe '#not_authenticated' do
    it 'redirects to operator_cat_in_path' do
      get :protected_action
      expect(response).to redirect_to(operator_cat_in_path)
    end

    it 'sets alert message with translation' do
      get :protected_action
      expect(flash[:alert]).to eq('セッションが切れました。再度ログインしてください。')
    end

    context 'when I18n translation is customized' do
      before do
        I18n.backend.store_translations(:ja, authentication: { errors: { session_expired: 'カスタムメッセージ' } })
      end

      after do
        I18n.backend.reload!
      end

      it 'uses custom I18n translation' do
        get :protected_action
        expect(flash[:alert]).to eq('カスタムメッセージ')
      end
    end
  end

  describe '#set_current_operator (private)' do
    context 'when operator_id exists in session' do
      before do
        controller.session[:operator_id] = operator.id
      end

      it 'sets @current_operator from session' do
        controller.send(:set_current_operator)
        expect(controller.instance_variable_get(:@current_operator)).to eq(operator)
      end

      it 'queries database only once (memoization)' do
        controller.send(:set_current_operator)
        expect(Operator).not_to receive(:find_by)
        controller.send(:set_current_operator)
      end
    end

    context 'when operator_id does not exist in session' do
      it 'does not set @current_operator' do
        controller.send(:set_current_operator)
        expect(controller.instance_variable_get(:@current_operator)).to be_nil
      end
    end

    context 'when operator_id is invalid' do
      before do
        controller.session[:operator_id] = 99_999
      end

      it 'resets session' do
        controller.send(:set_current_operator)
        expect(controller.session[:operator_id]).to be_nil
      end

      it 'returns nil' do
        result = controller.send(:set_current_operator)
        expect(result).to be_nil
      end
    end
  end

  describe 'helper methods' do
    it 'makes current_operator available in views' do
      expect(controller.class._helper_methods).to include(:current_operator)
    end

    it 'makes operator_signed_in? available in views' do
      expect(controller.class._helper_methods).to include(:operator_signed_in?)
    end
  end

  describe 'before_action :set_current_operator' do
    before do
      controller.session[:operator_id] = operator.id
    end

    it 'is called before each action' do
      expect(controller).to receive(:set_current_operator).and_call_original
      get :public_action
    end

    it 'sets current_operator before action' do
      get :public_action
      expect(controller.current_operator).to eq(operator)
    end
  end

  describe 'session fixation protection' do
    it 'prevents session fixation on login' do
      # Set up a session with some data
      controller.session[:malicious_data] = 'hacker_value'
      controller.session.id

      # Login should reset the session
      controller.login(operator)

      # Session should be reset
      expect(controller.session[:malicious_data]).to be_nil
      expect(controller.session[:operator_id]).to eq(operator.id)
    end

    it 'prevents session fixation on logout' do
      controller.login(operator)
      controller.session[:some_data] = 'value'

      controller.logout

      expect(controller.session[:operator_id]).to be_nil
      expect(controller.session[:some_data]).to be_nil
    end
  end

  describe 'integration with BruteForceProtection' do
    let(:locked_operator) do
      create(:operator, password: 'Password123', password_confirmation: 'Password123').tap do |op|
        op.update(
          lock_expires_at: 1.hour.from_now,
          failed_logins_count: 5
        )
      end
    end

    let(:auth_result_locked_operator) do
      AuthResult.failed(:account_locked, user: locked_operator)
    end

    before do
      allow(AuthenticationService).to receive(:authenticate)
        .and_return(auth_result_locked_operator)
      allow(locked_operator).to receive(:mail_notice)
    end

    it 'sends notification when locked account attempts login' do
      expect(locked_operator).to receive(:mail_notice).with(request_ip)
      controller.authenticate_operator('locked@example.com', 'password123')
    end
  end
end
