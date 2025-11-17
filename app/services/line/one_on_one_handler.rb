# frozen_string_literal: true

module Line
  # One-on-one message handler service
  #
  # Handles direct messages (non-group context) with usage instructions
  # and responses to stickers.
  #
  # @example
  #   handler = Line::OneOnOneHandler.new(adapter)
  #   handler.handle(event)
  class OneOnOneHandler
    HOW_TO_USE = 'https://www.cat-reline.com/'

    # Initialize one-on-one handler with LINE adapter
    #
    # @param adapter [Line::ClientAdapter] LINE SDK adapter for API calls
    # @param content_sampler [Line::ContentSampler] Optional content sampler (for testing)
    def initialize(adapter, content_sampler: nil)
      @adapter = adapter
      @content_sampler = content_sampler || Line::ContentSampler.new
    end

    # Handle one-on-one message event
    #
    # @param event [Line::Bot::Event::Message] Message event
    def handle(event)
      message = build_message(event)
      @adapter.reply_message(event.reply_token, message)
    end

    private

    # Build response message based on event type
    def build_message(event)
      case event.type
      when Line::Bot::Event::MessageType::Text
        { type: 'text', text: "【ReLINE】の使い方はこちらで確認してほしいにゃ！🐱🐾#{HOW_TO_USE}" }
      when Line::Bot::Event::MessageType::Sticker
        content = @content_sampler.sample(:free)
        { type: 'text', text: "スタンプありがとうニャ！✨\nお礼にこちらをお送りするニャ🐾🐾\n#{content.body}" }
      else
        { type: 'text', text: 'ごめんニャ😿分からないニャ。。。' }
      end
    end
  end
end
