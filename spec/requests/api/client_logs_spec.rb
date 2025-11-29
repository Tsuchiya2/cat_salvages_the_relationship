# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::ClientLogs', type: :request do
  describe 'POST /api/client_logs' do
    let(:valid_logs) do
      {
        logs: [
          { level: 'error', message: 'Test error', context: { key: 'value' }, url: 'http://example.com', trace_id: 'abc123' },
          { level: 'warn', message: 'Test warning', context: {}, url: 'http://example.com', trace_id: 'abc123' }
        ]
      }
    end

    context 'with valid logs' do
      it 'returns created status' do
        post '/api/client_logs', params: valid_logs, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'creates log entries' do
        expect do
          post '/api/client_logs', params: valid_logs, as: :json
        end.to change(ClientLog, :count).by(2)
      end

      it 'returns success response' do
        post '/api/client_logs', params: valid_logs, as: :json
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['count']).to eq(2)
      end

      it 'stores user_agent from request' do
        post '/api/client_logs', params: valid_logs, as: :json, headers: { 'User-Agent' => 'Test Browser' }
        log = ClientLog.last
        expect(log.user_agent).to eq('Test Browser')
      end

      it 'stores log with correct level' do
        post '/api/client_logs', params: valid_logs, as: :json
        error_log = ClientLog.find_by(level: 'error')
        expect(error_log.message).to eq('Test error')
        expect(error_log.context).to eq({ 'key' => 'value' })
      end

      it 'stores log with correct url and trace_id' do
        post '/api/client_logs', params: valid_logs, as: :json
        log = ClientLog.last
        expect(log.url).to eq('http://example.com')
        expect(log.trace_id).to eq('abc123')
      end
    end

    context 'with invalid logs' do
      it 'returns unprocessable_entity when logs is empty' do
        post '/api/client_logs', params: { logs: [] }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity when logs is missing' do
        post '/api/client_logs', params: {}, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity for invalid level' do
        invalid_logs = { logs: [{ level: 'invalid', message: 'Test' }] }
        post '/api/client_logs', params: invalid_logs, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity when message is missing' do
        invalid_logs = { logs: [{ level: 'error' }] }
        post '/api/client_logs', params: invalid_logs, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity when level is missing' do
        invalid_logs = { logs: [{ message: 'Test message' }] }
        post '/api/client_logs', params: invalid_logs, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create logs when validation fails' do
        invalid_logs = { logs: [{ level: 'invalid', message: 'Test' }] }
        expect do
          post '/api/client_logs', params: invalid_logs, as: :json
        end.not_to change(ClientLog, :count)
      end

      it 'returns error message for invalid entries' do
        invalid_logs = { logs: [{ level: 'invalid', message: 'Test' }] }
        post '/api/client_logs', params: invalid_logs, as: :json
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid log entries')
        expect(json['details']).to eq(1)
      end
    end

    context 'rate limiting' do
      it 'accepts up to 100 logs per request' do
        logs = { logs: Array.new(100) { { level: 'info', message: 'Test' } } }
        post '/api/client_logs', params: logs, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'rejects more than 100 logs per request' do
        logs = { logs: Array.new(101) { { level: 'info', message: 'Test' } } }
        post '/api/client_logs', params: logs, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message when exceeding limit' do
        logs = { logs: Array.new(101) { { level: 'info', message: 'Test' } } }
        post '/api/client_logs', params: logs, as: :json
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Maximum 100 logs per request')
      end

      it 'creates exactly 100 logs when at limit' do
        logs = { logs: Array.new(100) { { level: 'info', message: 'Test' } } }
        expect do
          post '/api/client_logs', params: logs, as: :json
        end.to change(ClientLog, :count).by(100)
      end
    end

    context 'CSRF protection' do
      it 'does not require CSRF token' do
        post '/api/client_logs', params: valid_logs, as: :json
        expect(response).not_to have_http_status(:unprocessable_entity)
      end

      it 'accepts request without authenticity token' do
        post '/api/client_logs', params: valid_logs, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'batch insert functionality' do
      it 'uses batch insert for performance' do
        expect(ClientLog).to receive(:insert_all).once
        post '/api/client_logs', params: valid_logs, as: :json
      end

      it 'creates all logs in single operation' do
        logs = { logs: Array.new(50) { |i| { level: 'info', message: "Test #{i}" } } }
        expect do
          post '/api/client_logs', params: logs, as: :json
        end.to change(ClientLog, :count).by(50)
      end
    end

    context 'with all valid log levels' do
      it 'accepts error level' do
        logs = { logs: [{ level: 'error', message: 'Error message' }] }
        post '/api/client_logs', params: logs, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts warn level' do
        logs = { logs: [{ level: 'warn', message: 'Warning message' }] }
        post '/api/client_logs', params: logs, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts info level' do
        logs = { logs: [{ level: 'info', message: 'Info message' }] }
        post '/api/client_logs', params: logs, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts debug level' do
        logs = { logs: [{ level: 'debug', message: 'Debug message' }] }
        post '/api/client_logs', params: logs, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'error handling' do
      it 'handles internal server errors gracefully' do
        allow(ClientLog).to receive(:insert_all).and_raise(StandardError, 'Database error')
        post '/api/client_logs', params: valid_logs, as: :json
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns error message for internal errors' do
        allow(ClientLog).to receive(:insert_all).and_raise(StandardError, 'Database error')
        post '/api/client_logs', params: valid_logs, as: :json
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Internal server error')
      end

      it 'logs error details' do
        allow(ClientLog).to receive(:insert_all).and_raise(StandardError, 'Database error')
        expect(Rails.logger).to receive(:error).with(/ClientLogsController error/)
        post '/api/client_logs', params: valid_logs, as: :json
      end
    end
  end
end
