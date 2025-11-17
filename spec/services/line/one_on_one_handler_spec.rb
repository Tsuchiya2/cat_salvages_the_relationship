# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::OneOnOneHandler do
  let(:adapter) { instance_double(Line::ClientAdapter) }
  let(:handler) { described_class.new(adapter) }

  before do
    allow(adapter).to receive(:reply_message)
    # Stub LINE event type constants
    stub_const('Line::Bot::Event::MessageType::Text', 'text')
    stub_const('Line::Bot::Event::MessageType::Sticker', 'sticker')
    stub_const('Line::Bot::Event::MessageType::Image', 'image')
  end

  describe '#handle' do
    let(:reply_token) { 'REPLY123' }

    context 'with text message' do
      let(:event) do
        double(
          'Message Event',
          type: 'text',
          reply_token: reply_token
        )
      end

      it 'sends usage instructions' do
        handler.handle(event)

        expect(adapter).to have_received(:reply_message).with(
          reply_token,
          hash_including(
            type: 'text',
            text: match(/ReLINE.*使い方/)
          )
        )
      end

      it 'includes website URL in response' do
        handler.handle(event)

        expect(adapter).to have_received(:reply_message).with(
          reply_token,
          hash_including(text: match(/cat-reline.com/))
        )
      end
    end

    context 'with sticker message' do
      let(:event) do
        double(
          'Message Event',
          type: 'sticker',
          reply_token: reply_token
        )
      end

      before do
        create(:content, category: :free, body: 'Sample free content')
      end

      it 'sends thank you message with sample content' do
        handler.handle(event)

        expect(adapter).to have_received(:reply_message).with(
          reply_token,
          hash_including(
            type: 'text',
            text: match(/スタンプありがとうニャ/)
          )
        )
      end

      it 'includes random content in response' do
        handler.handle(event)

        expect(adapter).to have_received(:reply_message) do |_token, message|
          expect(message[:text]).to match(/Sample free content/)
        end
      end
    end

    context 'with unknown message type' do
      let(:event) do
        double(
          'Message Event',
          type: 'unknown',
          reply_token: reply_token
        )
      end

      it 'sends default response' do
        handler.handle(event)

        expect(adapter).to have_received(:reply_message).with(
          reply_token,
          hash_including(
            type: 'text',
            text: match(/ごめんニャ.*分からないニャ/)
          )
        )
      end
    end

    context 'with image message' do
      let(:event) do
        double(
          'Message Event',
          type: 'image',
          reply_token: reply_token
        )
      end

      it 'sends default response for unsupported type' do
        handler.handle(event)

        expect(adapter).to have_received(:reply_message).with(
          reply_token,
          hash_including(
            type: 'text',
            text: match(/ごめんニャ/)
          )
        )
      end
    end
  end
end
