# frozen_string_literal: true

require 'rails_helper'
require 'line/bot'

RSpec.describe Line::ClientAdapter do
  describe 'abstract interface' do
    subject(:adapter) { described_class.new }

    it 'raises NotImplementedError for validate_signature' do
      expect { adapter.validate_signature('body', 'signature') }
        .to raise_error(NotImplementedError, /must implement #validate_signature/)
    end

    it 'raises NotImplementedError for parse_events' do
      expect { adapter.parse_events('body') }
        .to raise_error(NotImplementedError, /must implement #parse_events/)
    end

    it 'raises NotImplementedError for push_message' do
      expect { adapter.push_message('target', {}) }
        .to raise_error(NotImplementedError, /must implement #push_message/)
    end

    it 'raises NotImplementedError for reply_message' do
      expect { adapter.reply_message('token', {}) }
        .to raise_error(NotImplementedError, /must implement #reply_message/)
    end

    it 'raises NotImplementedError for get_group_member_count' do
      expect { adapter.get_group_member_count('group123') }
        .to raise_error(NotImplementedError, /must implement #get_group_member_count/)
    end

    it 'raises NotImplementedError for get_room_member_count' do
      expect { adapter.get_room_member_count('room123') }
        .to raise_error(NotImplementedError, /must implement #get_room_member_count/)
    end

    it 'raises NotImplementedError for leave_group' do
      expect { adapter.leave_group('group123') }
        .to raise_error(NotImplementedError, /must implement #leave_group/)
    end

    it 'raises NotImplementedError for leave_room' do
      expect { adapter.leave_room('room123') }
        .to raise_error(NotImplementedError, /must implement #leave_room/)
    end
  end
end

RSpec.describe Line::SdkV2Adapter do
  let(:credentials) do
    {
      channel_id: 'test_channel_id',
      channel_secret: 'test_channel_secret',
      channel_token: 'test_channel_token'
    }
  end

  let(:mock_client) { double('Line::Bot::Client') }

  before do
    # Stub the Line::Bot::Client constant to allow mocking
    line_bot_module = Module.new do
      def self.const_missing(name)
        if name == :Client
          Class.new
        else
          super
        end
      end
    end

    unless defined?(Line::Bot::Client)
      stub_const('Line::Bot', line_bot_module)
      stub_const('Line::Bot::Client', Class.new)
    end

    allow(Line::Bot::Client).to receive(:new).and_return(mock_client)
  end

  describe '#initialize' do
    it 'creates Line::Bot::Client with credentials' do
      described_class.new(credentials)

      expect(Line::Bot::Client).to have_received(:new)
    end

    it 'raises ArgumentError when channel_id is missing' do
      invalid_credentials = credentials.except(:channel_id)

      expect { described_class.new(invalid_credentials) }
        .to raise_error(ArgumentError, /Missing LINE credentials: channel_id/)
    end

    it 'raises ArgumentError when channel_secret is missing' do
      invalid_credentials = credentials.except(:channel_secret)

      expect { described_class.new(invalid_credentials) }
        .to raise_error(ArgumentError, /Missing LINE credentials: channel_secret/)
    end

    it 'raises ArgumentError when channel_token is missing' do
      invalid_credentials = credentials.except(:channel_token)

      expect { described_class.new(invalid_credentials) }
        .to raise_error(ArgumentError, /Missing LINE credentials: channel_token/)
    end

    it 'raises ArgumentError when multiple credentials are missing' do
      invalid_credentials = { channel_id: 'test' }

      expect { described_class.new(invalid_credentials) }
        .to raise_error(ArgumentError, /Missing LINE credentials: channel_secret, channel_token/)
    end
  end

  describe '#validate_signature' do
    subject(:adapter) { described_class.new(credentials) }

    it 'delegates to SDK client' do
      allow(mock_client).to receive(:validate_signature).and_return(true)

      result = adapter.validate_signature('body', 'signature')

      expect(result).to be true
      expect(mock_client).to have_received(:validate_signature).with('body', 'signature')
    end
  end

  describe '#parse_events' do
    subject(:adapter) { described_class.new(credentials) }

    it 'delegates to SDK client' do
      mock_events = [double('Event')]
      allow(mock_client).to receive(:parse_events_from).and_return(mock_events)

      result = adapter.parse_events('{"events":[]}')

      expect(result).to eq(mock_events)
      expect(mock_client).to have_received(:parse_events_from).with('{"events":[]}')
    end
  end

  describe '#push_message' do
    subject(:adapter) { described_class.new(credentials) }

    let(:mock_response) { instance_double(Net::HTTPResponse, code: '200') }

    before do
      allow(mock_client).to receive(:push_message).and_return(mock_response)
      allow(PrometheusMetrics).to receive(:track_line_api_call)
    end

    it 'sends message via SDK client' do
      message = { type: 'text', text: 'Hello' }

      adapter.push_message('GROUP123', message)

      expect(mock_client).to have_received(:push_message).with('GROUP123', message)
    end

    it 'tracks metrics for API call' do
      message = { type: 'text', text: 'Hello' }

      adapter.push_message('GROUP123', message)

      expect(PrometheusMetrics).to have_received(:track_line_api_call)
        .with('push_message', '200', kind_of(Numeric))
    end

    it 'returns response from SDK client' do
      message = { type: 'text', text: 'Hello' }

      result = adapter.push_message('GROUP123', message)

      expect(result).to eq(mock_response)
    end
  end

  describe '#reply_message' do
    subject(:adapter) { described_class.new(credentials) }

    let(:mock_response) { instance_double(Net::HTTPResponse, code: '200') }

    before do
      allow(mock_client).to receive(:reply_message).and_return(mock_response)
      allow(PrometheusMetrics).to receive(:track_line_api_call)
    end

    it 'sends reply via SDK client' do
      message = { type: 'text', text: 'Hello' }

      adapter.reply_message('REPLY_TOKEN', message)

      expect(mock_client).to have_received(:reply_message).with('REPLY_TOKEN', message)
    end

    it 'tracks metrics for API call' do
      message = { type: 'text', text: 'Hello' }

      adapter.reply_message('REPLY_TOKEN', message)

      expect(PrometheusMetrics).to have_received(:track_line_api_call)
        .with('reply_message', '200', kind_of(Numeric))
    end
  end

  describe '#get_group_member_count' do
    subject(:adapter) { described_class.new(credentials) }

    before do
      allow(mock_client).to receive(:get_group_members_count)
        .and_return({ 'count' => 5 })
      allow(PrometheusMetrics).to receive(:track_line_api_call)
    end

    it 'queries member count via SDK client' do
      adapter.get_group_member_count('GROUP123')

      expect(mock_client).to have_received(:get_group_members_count).with('GROUP123')
    end

    it 'returns count as integer' do
      result = adapter.get_group_member_count('GROUP123')

      expect(result).to eq(5)
      expect(result).to be_an(Integer)
    end

    it 'tracks metrics for API call' do
      adapter.get_group_member_count('GROUP123')

      expect(PrometheusMetrics).to have_received(:track_line_api_call)
        .with('get_group_members_count', '200', kind_of(Numeric))
    end
  end

  describe '#get_room_member_count' do
    subject(:adapter) { described_class.new(credentials) }

    before do
      allow(mock_client).to receive(:get_room_members_count)
        .and_return({ 'count' => 3 })
      allow(PrometheusMetrics).to receive(:track_line_api_call)
    end

    it 'queries member count via SDK client' do
      adapter.get_room_member_count('ROOM123')

      expect(mock_client).to have_received(:get_room_members_count).with('ROOM123')
    end

    it 'returns count as integer' do
      result = adapter.get_room_member_count('ROOM123')

      expect(result).to eq(3)
      expect(result).to be_an(Integer)
    end

    it 'tracks metrics for API call' do
      adapter.get_room_member_count('ROOM123')

      expect(PrometheusMetrics).to have_received(:track_line_api_call)
        .with('get_room_members_count', '200', kind_of(Numeric))
    end
  end

  describe '#leave_group' do
    subject(:adapter) { described_class.new(credentials) }

    let(:mock_response) { instance_double(Net::HTTPResponse, code: '200') }

    before do
      allow(mock_client).to receive(:leave_group).and_return(mock_response)
    end

    it 'leaves group via SDK client' do
      adapter.leave_group('GROUP123')

      expect(mock_client).to have_received(:leave_group).with('GROUP123')
    end

    it 'returns response from SDK client' do
      result = adapter.leave_group('GROUP123')

      expect(result).to eq(mock_response)
    end
  end

  describe '#leave_room' do
    subject(:adapter) { described_class.new(credentials) }

    let(:mock_response) { instance_double(Net::HTTPResponse, code: '200') }

    before do
      allow(mock_client).to receive(:leave_room).and_return(mock_response)
    end

    it 'leaves room via SDK client' do
      adapter.leave_room('ROOM123')

      expect(mock_client).to have_received(:leave_room).with('ROOM123')
    end

    it 'returns response from SDK client' do
      result = adapter.leave_room('ROOM123')

      expect(result).to eq(mock_response)
    end
  end
end
