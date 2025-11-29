# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Metrics', type: :request do
  describe 'POST /api/metrics' do
    let(:valid_metrics) do
      {
        metrics: [
          { name: 'cache_hit', value: 1, unit: 'count', tags: { strategy: 'cache-first' }, trace_id: 'abc123' },
          { name: 'response_time', value: 150.5, unit: 'ms', tags: {}, trace_id: 'abc123' }
        ]
      }
    end

    context 'with valid metrics' do
      it 'returns created status' do
        post '/api/metrics', params: valid_metrics, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'creates metric entries' do
        expect do
          post '/api/metrics', params: valid_metrics, as: :json
        end.to change(Metric, :count).by(2)
      end

      it 'returns success response' do
        post '/api/metrics', params: valid_metrics, as: :json
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['count']).to eq(2)
      end

      it 'stores metric with correct values' do
        post '/api/metrics', params: valid_metrics, as: :json
        metric = Metric.find_by(name: 'cache_hit')
        expect(metric.value).to eq(1)
        expect(metric.unit).to eq('count')
      end

      it 'stores tags as JSON' do
        post '/api/metrics', params: valid_metrics, as: :json
        metric = Metric.find_by(name: 'cache_hit')
        expect(metric.tags).to eq({ 'strategy' => 'cache-first' })
      end

      it 'stores decimal values correctly' do
        post '/api/metrics', params: valid_metrics, as: :json
        metric = Metric.find_by(name: 'response_time')
        expect(metric.value).to eq(150.5)
      end

      it 'stores trace_id for correlation' do
        post '/api/metrics', params: valid_metrics, as: :json
        metric = Metric.last
        expect(metric.trace_id).to eq('abc123')
      end

      it 'accepts metrics without unit' do
        metrics = { metrics: [{ name: 'test_metric', value: 10 }] }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts metrics without tags' do
        metrics = { metrics: [{ name: 'test_metric', value: 10 }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.tags).to be_nil
      end

      it 'accepts metrics without trace_id' do
        metrics = { metrics: [{ name: 'test_metric', value: 10 }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.trace_id).to be_nil
      end
    end

    context 'with invalid metrics' do
      it 'returns unprocessable_entity when metrics is empty' do
        post '/api/metrics', params: { metrics: [] }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity when metrics is missing' do
        post '/api/metrics', params: {}, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity when name is missing' do
        invalid_metrics = { metrics: [{ value: 1 }] }
        post '/api/metrics', params: invalid_metrics, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'accepts metrics with value as 0 (missing value becomes 0)' do
        # Note: Missing value is converted to 0 by .to_d
        metrics = { metrics: [{ name: 'test' }] }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
        metric = Metric.last
        expect(metric.value).to eq(0)
      end

      it 'returns unprocessable_entity when name is blank' do
        invalid_metrics = { metrics: [{ name: '', value: 1 }] }
        post '/api/metrics', params: invalid_metrics, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create metrics when validation fails' do
        invalid_metrics = { metrics: [{ name: '' }] }
        expect do
          post '/api/metrics', params: invalid_metrics, as: :json
        end.not_to change(Metric, :count)
      end

      it 'returns error message for invalid entries' do
        invalid_metrics = { metrics: [{ name: '', value: 1 }] }
        post '/api/metrics', params: invalid_metrics, as: :json
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid metric entries')
        expect(json['details']).to eq(1)
      end
    end

    context 'rate limiting' do
      it 'accepts up to 100 metrics per request' do
        metrics = { metrics: Array.new(100) { { name: 'test', value: 1 } } }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'rejects more than 100 metrics per request' do
        metrics = { metrics: Array.new(101) { { name: 'test', value: 1 } } }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message when exceeding limit' do
        metrics = { metrics: Array.new(101) { { name: 'test', value: 1 } } }
        post '/api/metrics', params: metrics, as: :json
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Maximum 100 metrics per request')
      end

      it 'creates exactly 100 metrics when at limit' do
        metrics = { metrics: Array.new(100) { |i| { name: "metric_#{i}", value: i } } }
        expect do
          post '/api/metrics', params: metrics, as: :json
        end.to change(Metric, :count).by(100)
      end
    end

    context 'CSRF protection' do
      it 'does not require CSRF token' do
        post '/api/metrics', params: valid_metrics, as: :json
        expect(response).not_to have_http_status(:unprocessable_entity)
      end

      it 'accepts request without authenticity token' do
        post '/api/metrics', params: valid_metrics, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'batch insert functionality' do
      it 'uses batch insert for performance' do
        expect(Metric).to receive(:insert_all).once
        post '/api/metrics', params: valid_metrics, as: :json
      end

      it 'creates all metrics in single operation' do
        metrics = { metrics: Array.new(50) { |i| { name: "metric_#{i}", value: i } } }
        expect do
          post '/api/metrics', params: metrics, as: :json
        end.to change(Metric, :count).by(50)
      end
    end

    context 'with various metric types' do
      it 'accepts cache hit metrics' do
        metrics = { metrics: [{ name: 'cache_hit', value: 1, unit: 'count' }] }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts service worker registration metrics' do
        metrics = { metrics: [{ name: 'service_worker_registration', value: 1, unit: 'count' }] }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts response time metrics' do
        metrics = { metrics: [{ name: 'response_time', value: 250.5, unit: 'ms' }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.value).to eq(250.5)
        expect(metric.unit).to eq('ms')
      end

      it 'accepts install prompt metrics' do
        metrics = { metrics: [{ name: 'install_prompt_shown', value: 1, unit: 'count' }] }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'accepts app installed metrics' do
        metrics = { metrics: [{ name: 'app_installed', value: 1, unit: 'count' }] }
        post '/api/metrics', params: metrics, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'with complex tags' do
      it 'stores complex tag structures' do
        metrics = {
          metrics: [{
            name: 'test',
            value: 1,
            tags: { strategy: 'cache-first', resource: 'image', size: 'large' }
          }]
        }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.tags).to eq({
          'strategy' => 'cache-first',
          'resource' => 'image',
          'size' => 'large'
        })
      end

      it 'handles empty tags object' do
        metrics = { metrics: [{ name: 'test', value: 1, tags: {} }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.tags).to eq({})
      end
    end

    context 'value conversion' do
      it 'converts integer values to decimal' do
        metrics = { metrics: [{ name: 'test', value: 100 }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.value).to be_a(BigDecimal)
        expect(metric.value).to eq(100)
      end

      it 'converts float values to decimal' do
        metrics = { metrics: [{ name: 'test', value: 123.45 }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.value).to be_a(BigDecimal)
        expect(metric.value).to eq(123.45)
      end

      it 'handles zero values' do
        metrics = { metrics: [{ name: 'test', value: 0 }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.value).to eq(0)
      end

      it 'handles negative values' do
        metrics = { metrics: [{ name: 'test', value: -10 }] }
        post '/api/metrics', params: metrics, as: :json
        metric = Metric.last
        expect(metric.value).to eq(-10)
      end
    end

    context 'error handling' do
      it 'handles internal server errors gracefully' do
        allow(Metric).to receive(:insert_all).and_raise(StandardError, 'Database error')
        post '/api/metrics', params: valid_metrics, as: :json
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns error message for internal errors' do
        allow(Metric).to receive(:insert_all).and_raise(StandardError, 'Database error')
        post '/api/metrics', params: valid_metrics, as: :json
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Internal server error')
      end

      it 'logs error details' do
        allow(Metric).to receive(:insert_all).and_raise(StandardError, 'Database error')
        expect(Rails.logger).to receive(:error).with(/MetricsController error/)
        post '/api/metrics', params: valid_metrics, as: :json
      end
    end
  end
end
