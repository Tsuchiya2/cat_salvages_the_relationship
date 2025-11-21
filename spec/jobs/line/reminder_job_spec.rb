# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::ReminderJob, type: :job do
  include ActiveJob::TestHelper

  let(:adapter) { instance_double(Line::SdkV2Adapter) }
  let(:response) { instance_double(Net::HTTPResponse, code: '200') }
  let(:messages) { [{ type: 'text', text: 'a' }, { type: 'text', text: 'b' }] }

  before do
    allow(Line::ClientProvider).to receive(:client).and_return(adapter)
    allow(adapter).to receive(:push_message).and_return(response)
    allow(PrometheusMetrics).to receive(:track_message_send)
  end

  it 'sends all messages and tracks success' do
    described_class.perform_now('GROUP1', messages)

    expect(adapter).to have_received(:push_message).with('GROUP1', messages[0]).once
    expect(adapter).to have_received(:push_message).with('GROUP1', messages[1]).once
    expect(PrometheusMetrics).to have_received(:track_message_send).with('success').twice
  end

  it 'raises after retries on 400 and tracks error' do
    bad_response = instance_double(Net::HTTPResponse, code: '400')
    allow(adapter).to receive(:push_message).and_return(bad_response)

    expect do
      described_class.perform_now('GROUP1', [messages.first])
    end.to raise_error(StandardError)

    expect(PrometheusMetrics).to have_received(:track_message_send).with('error')
  end
end
