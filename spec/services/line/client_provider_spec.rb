# frozen_string_literal: true

require 'rails_helper'
require 'line/bot'

RSpec.describe Line::ClientProvider do
  describe '.client' do
    let(:mock_credentials) do
      {
        channel_id: 'test_channel_id',
        channel_secret: 'test_channel_secret',
        channel_token: 'test_channel_token'
      }
    end

    before do
      # Stub the Line::Bot::Client constant to allow mocking
      unless defined?(Line::Bot::Client)
        stub_const('Line::Bot::Client', Class.new)
      end

      allow(Rails.application.credentials).to receive(:channel_id).and_return(mock_credentials[:channel_id])
      allow(Rails.application.credentials).to receive(:channel_secret).and_return(mock_credentials[:channel_secret])
      allow(Rails.application.credentials).to receive(:channel_token).and_return(mock_credentials[:channel_token])

      # Reset singleton before each test
      described_class.reset!
    end

    after do
      # Clean up after each test
      described_class.reset!
    end

    it 'returns a SdkV2Adapter instance' do
      client = described_class.client

      expect(client).to be_a(Line::SdkV2Adapter)
    end

    it 'memoizes the client instance' do
      client1 = described_class.client
      client2 = described_class.client

      expect(client1).to be(client2)
      expect(client1.object_id).to eq(client2.object_id)
    end

    it 'loads credentials from Rails.application.credentials' do
      expect(Rails.application.credentials).to receive(:channel_id)
      expect(Rails.application.credentials).to receive(:channel_secret)
      expect(Rails.application.credentials).to receive(:channel_token)

      described_class.client
    end
  end

  describe '.reset!' do
    let(:mock_credentials) do
      {
        channel_id: 'test_channel_id',
        channel_secret: 'test_channel_secret',
        channel_token: 'test_channel_token'
      }
    end

    before do
      # Stub the Line::Bot::Client constant to allow mocking
      unless defined?(Line::Bot::Client)
        stub_const('Line::Bot::Client', Class.new)
      end

      allow(Rails.application.credentials).to receive(:channel_id).and_return(mock_credentials[:channel_id])
      allow(Rails.application.credentials).to receive(:channel_secret).and_return(mock_credentials[:channel_secret])
      allow(Rails.application.credentials).to receive(:channel_token).and_return(mock_credentials[:channel_token])
    end

    it 'clears the memoized client' do
      client1 = described_class.client
      described_class.reset!
      client2 = described_class.client

      expect(client1).not_to be(client2)
      expect(client1.object_id).not_to eq(client2.object_id)
    end

    it 'returns nil' do
      result = described_class.reset!

      expect(result).to be_nil
    end
  end
end
