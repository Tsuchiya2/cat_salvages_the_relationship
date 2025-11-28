# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionManager do
  let(:operator) { instance_double(Operator, id: 1) }
  let(:customer) { instance_double(Operator, id: 2) }
  let(:session) { {} }

  describe '.create_session' do
    context 'with default key' do
      it 'stores user ID in session' do
        described_class.create_session(operator, session)

        expect(session[:user_id]).to eq(1)
      end

      it 'stores session creation timestamp' do
        freeze_time do
          described_class.create_session(operator, session)

          expect(session[:session_created_at]).to eq(Time.current)
        end
      end
    end

    context 'with custom key' do
      it 'stores user ID with custom session key' do
        described_class.create_session(customer, session, key: :customer_id)

        expect(session[:customer_id]).to eq(2)
      end

      it 'stores session creation timestamp' do
        freeze_time do
          described_class.create_session(customer, session, key: :customer_id)

          expect(session[:session_created_at]).to eq(Time.current)
        end
      end
    end

    context 'with multiple users in same session' do
      it 'supports multiple user types with different keys' do
        described_class.create_session(operator, session, key: :operator_id)
        described_class.create_session(customer, session, key: :customer_id)

        expect(session[:operator_id]).to eq(1)
        expect(session[:customer_id]).to eq(2)
      end

      it 'updates timestamp on subsequent session creation' do
        freeze_time do
          described_class.create_session(operator, session, key: :operator_id)
          first_timestamp = session[:session_created_at]

          travel 5.minutes

          described_class.create_session(customer, session, key: :customer_id)
          second_timestamp = session[:session_created_at]

          expect(second_timestamp).to be > first_timestamp
          expect(second_timestamp).to eq(Time.current)
        end
      end
    end
  end

  describe '.destroy_session' do
    before do
      session[:user_id] = 1
      session[:session_created_at] = Time.current
      session[:other_data] = 'some value'
    end

    it 'clears all session data' do
      described_class.destroy_session(session)

      expect(session[:user_id]).to be_nil
      expect(session[:session_created_at]).to be_nil
      expect(session[:other_data]).to be_nil
    end

    it 'empties the session' do
      described_class.destroy_session(session)

      expect(session).to be_empty
    end
  end

  describe '.current_user' do
    let(:operator_model) { class_double(Operator) }

    context 'when user ID exists in session' do
      before do
        session[:user_id] = 1
        allow(operator_model).to receive(:find_by).with(id: 1).and_return(operator)
      end

      it 'retrieves user from database' do
        result = described_class.current_user(session, operator_model)

        expect(result).to eq(operator)
        expect(operator_model).to have_received(:find_by).with(id: 1)
      end
    end

    context 'when user ID does not exist in session' do
      before do
        session[:user_id] = nil
        allow(operator_model).to receive(:find_by)
      end

      it 'returns nil without database query' do
        result = described_class.current_user(session, operator_model)

        expect(result).to be_nil
        expect(operator_model).not_to have_received(:find_by)
      end
    end

    context 'when user no longer exists in database' do
      before do
        session[:user_id] = 999
        allow(operator_model).to receive(:find_by).with(id: 999).and_return(nil)
      end

      it 'returns nil' do
        result = described_class.current_user(session, operator_model)

        expect(result).to be_nil
      end
    end

    context 'with custom session key' do
      before do
        session[:customer_id] = 2
        allow(operator_model).to receive(:find_by).with(id: 2).and_return(customer)
      end

      it 'retrieves user using custom key' do
        result = described_class.current_user(session, operator_model, key: :customer_id)

        expect(result).to eq(customer)
        expect(operator_model).to have_received(:find_by).with(id: 2)
      end
    end

    context 'with multiple user types' do
      let(:customer_model) { class_double(Operator) }

      before do
        session[:operator_id] = 1
        session[:customer_id] = 2
        allow(operator_model).to receive(:find_by).with(id: 1).and_return(operator)
        allow(customer_model).to receive(:find_by).with(id: 2).and_return(customer)
      end

      it 'retrieves correct user based on key and model class' do
        operator_result = described_class.current_user(session, operator_model, key: :operator_id)
        customer_result = described_class.current_user(session, customer_model, key: :customer_id)

        expect(operator_result).to eq(operator)
        expect(customer_result).to eq(customer)
      end
    end
  end

  describe '.valid_session?' do
    context 'when session creation timestamp exists' do
      context 'when session is within timeout period' do
        before do
          session[:session_created_at] = 20.minutes.ago
        end

        it 'returns true with default timeout (30 minutes)' do
          result = described_class.valid_session?(session)

          expect(result).to be true
        end

        it 'returns true with custom timeout' do
          result = described_class.valid_session?(session, timeout: 1.hour)

          expect(result).to be true
        end
      end

      context 'when session has exceeded timeout period' do
        before do
          session[:session_created_at] = 40.minutes.ago
        end

        it 'returns false with default timeout (30 minutes)' do
          result = described_class.valid_session?(session)

          expect(result).to be false
        end

        it 'returns true with longer custom timeout' do
          result = described_class.valid_session?(session, timeout: 1.hour)

          expect(result).to be true
        end

        it 'returns false with shorter custom timeout' do
          result = described_class.valid_session?(session, timeout: 15.minutes)

          expect(result).to be false
        end
      end

      context 'when session is exactly at timeout boundary' do
        before do
          session[:session_created_at] = 30.minutes.ago
        end

        it 'returns false (not greater than timeout.ago)' do
          result = described_class.valid_session?(session)

          expect(result).to be false
        end
      end

      context 'with Time object stored in session' do
        before do
          freeze_time do
            session[:session_created_at] = Time.current
          end
        end

        it 'handles Time objects correctly' do
          travel 10.minutes

          result = described_class.valid_session?(session)

          expect(result).to be true
        end
      end

      context 'with string timestamp stored in session' do
        before do
          session[:session_created_at] = 15.minutes.ago.to_s
        end

        it 'parses string timestamp correctly' do
          result = described_class.valid_session?(session)

          expect(result).to be true
        end
      end
    end

    context 'when session creation timestamp is missing' do
      before do
        session[:session_created_at] = nil
      end

      it 'returns false' do
        result = described_class.valid_session?(session)

        expect(result).to be false
      end

      it 'returns false regardless of timeout setting' do
        result = described_class.valid_session?(session, timeout: 1.hour)

        expect(result).to be false
      end
    end

    context 'when session is empty' do
      it 'returns false' do
        result = described_class.valid_session?(session)

        expect(result).to be false
      end
    end
  end

  describe 'integration scenarios' do
    let(:operator_model) { class_double(Operator) }

    context 'complete session lifecycle' do
      it 'creates, validates, retrieves, and destroys session' do
        freeze_time do
          # Create session
          described_class.create_session(operator, session)
          expect(session[:user_id]).to eq(1)

          # Validate session
          expect(described_class.valid_session?(session)).to be true

          # Retrieve user
          allow(operator_model).to receive(:find_by).with(id: 1).and_return(operator)
          current = described_class.current_user(session, operator_model)
          expect(current).to eq(operator)

          # Destroy session
          described_class.destroy_session(session)
          expect(session).to be_empty
          expect(described_class.valid_session?(session)).to be false
        end
      end
    end

    context 'session timeout scenario' do
      it 'invalidates session after timeout period' do
        freeze_time do
          described_class.create_session(operator, session)
          expect(described_class.valid_session?(session)).to be true

          travel 20.minutes
          expect(described_class.valid_session?(session)).to be true

          travel 15.minutes # Total: 35 minutes
          expect(described_class.valid_session?(session)).to be false
        end
      end
    end

    context 'multiple concurrent user types' do
      let(:customer_model) { class_double(Operator) }

      it 'manages multiple user types independently' do
        # Create sessions for different user types
        described_class.create_session(operator, session, key: :operator_id)
        described_class.create_session(customer, session, key: :customer_id)

        # Verify both users can be retrieved
        allow(operator_model).to receive(:find_by).with(id: 1).and_return(operator)
        allow(customer_model).to receive(:find_by).with(id: 2).and_return(customer)

        operator_result = described_class.current_user(session, operator_model, key: :operator_id)
        customer_result = described_class.current_user(session, customer_model, key: :customer_id)

        expect(operator_result).to eq(operator)
        expect(customer_result).to eq(customer)

        # Verify session is valid for both
        expect(described_class.valid_session?(session)).to be true
      end
    end
  end
end
