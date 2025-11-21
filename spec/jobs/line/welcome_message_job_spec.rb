# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::WelcomeMessageJob, type: :job do
  include ActiveJob::TestHelper

  let(:adapter) { instance_double(Line::SdkV2Adapter, push_message: response) }
  let(:response) { instance_double(Net::HTTPResponse, code: '200') }
  let(:message) { { type: 'text', text: 'hi' } }

  before do
    allow(Line::ClientProvider).to receive(:client).and_return(adapter)
    allow(PrometheusMetrics).to receive(:track_message_send)
  end

  it 'pushes message via adapter and tracks success' do
    described_class.perform_now('GROUP1', message)

    expect(adapter).to have_received(:push_message).with('GROUP1', message)
    expect(PrometheusMetrics).to have_received(:track_message_send).with('success')
  end
end
