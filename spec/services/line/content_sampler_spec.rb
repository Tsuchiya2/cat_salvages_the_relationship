# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::ContentSampler do
  include ActiveSupport::Testing::TimeHelpers

  let(:sampler) { described_class.new }

  # Create test data
  let!(:free_content_1) { create(:content, category: :free, body: 'Free content 1') }
  let!(:free_content_2) { create(:content, category: :free, body: 'Free content 2') }
  let!(:contact_content) { create(:content, category: :contact, body: 'Contact content') }
  let!(:text_content) { create(:content, category: :text, body: 'Text content') }

  describe '#sample' do
    context 'without preloading' do
      it 'returns a random content from the specified category' do
        result = sampler.sample(:free)

        expect(result).to be_a(Content)
        expect(result.category).to eq('free')
      end

      it 'queries database on first call' do
        expect(Content).to receive(:free).and_call_original

        sampler.sample(:free)
      end

      it 'caches result for subsequent calls within cache duration' do
        sampler.sample(:free)

        expect(Content).not_to receive(:free)

        sampler.sample(:free)
      end
    end

    context 'with preloading' do
      before do
        sampler.preload_all
      end

      it 'does not query database after preloading' do
        expect(Content).not_to receive(:free)
        expect(Content).not_to receive(:contact)
        expect(Content).not_to receive(:text)

        sampler.sample(:free)
        sampler.sample(:contact)
        sampler.sample(:text)
      end

      it 'returns content from preloaded cache' do
        result = sampler.sample(:free)

        expect(result).to be_a(Content)
        expect([free_content_1, free_content_2]).to include(result)
      end

      it 'can handle multiple categories' do
        free_result = sampler.sample(:free)
        contact_result = sampler.sample(:contact)
        text_result = sampler.sample(:text)

        expect(free_result.category).to eq('free')
        expect(contact_result.category).to eq('contact')
        expect(text_result.category).to eq('text')
      end
    end

    context 'cache expiration' do
      it 'refreshes cache after expiration' do
        sampler.sample(:free)

        # Fast-forward time past cache expiration
        travel_to(described_class::CACHE_DURATION.from_now + 1.second) do
          expect(Content).to receive(:free).and_call_original

          sampler.sample(:free)
        end
      end
    end

    context 'with empty category' do
      before do
        Content.destroy_all
      end

      it 'returns nil when no content exists' do
        result = sampler.sample(:free)
        expect(result).to be_nil
      end
    end
  end

  describe '#preload_all' do
    it 'loads all content categories' do
      expect(Content).to receive(:free).once.and_call_original
      expect(Content).to receive(:contact).once.and_call_original
      expect(Content).to receive(:text).once.and_call_original

      sampler.preload_all
    end

    it 'caches content for all categories' do
      sampler.preload_all

      expect(sampler.cached_content(:free)).to be_an(Array)
      expect(sampler.cached_content(:contact)).to be_an(Array)
      expect(sampler.cached_content(:text)).to be_an(Array)
    end

    it 'reduces queries in batch operations' do
      sampler.preload_all

      query_count = count_queries do
        100.times { sampler.sample(:free) }
      end

      expect(query_count).to eq(0)
    end
  end

  describe '#cached_content' do
    it 'returns nil for non-cached category' do
      expect(sampler.cached_content(:free)).to be_nil
    end

    it 'returns cached array after preloading' do
      sampler.preload_all

      cached = sampler.cached_content(:free)

      expect(cached).to be_an(Array)
      expect(cached.length).to eq(2)
    end
  end

  # Helper method to count database queries
  def count_queries(&block)
    count = 0
    counter = ->(*, **) { count += 1 }

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)

    count
  end
end
