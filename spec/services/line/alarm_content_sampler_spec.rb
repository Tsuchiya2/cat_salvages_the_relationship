# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::AlarmContentSampler do
  include ActiveSupport::Testing::TimeHelpers

  let(:sampler) { described_class.new }

  # Create test data
  let!(:contact_content_1) { create(:alarm_content, category: :contact, body: 'Contact alarm 1') }
  let!(:contact_content_2) { create(:alarm_content, category: :contact, body: 'Contact alarm 2') }
  let!(:text_content) { create(:alarm_content, category: :text, body: 'Text alarm') }

  describe '#sample' do
    context 'without preloading' do
      it 'returns a random alarm content from the specified category' do
        result = sampler.sample(:contact)

        expect(result).to be_a(AlarmContent)
        expect(result.category).to eq('contact')
      end

      it 'queries database on first call' do
        expect(AlarmContent).to receive(:contact).and_call_original

        sampler.sample(:contact)
      end

      it 'caches result for subsequent calls within cache duration' do
        sampler.sample(:contact)

        expect(AlarmContent).not_to receive(:contact)

        sampler.sample(:contact)
      end
    end

    context 'with preloading' do
      before do
        sampler.preload_all
      end

      it 'does not query database after preloading' do
        expect(AlarmContent).not_to receive(:contact)
        expect(AlarmContent).not_to receive(:text)

        sampler.sample(:contact)
        sampler.sample(:text)
      end

      it 'returns content from preloaded cache' do
        result = sampler.sample(:contact)

        expect(result).to be_a(AlarmContent)
        expect([contact_content_1, contact_content_2]).to include(result)
      end

      it 'can handle multiple categories' do
        contact_result = sampler.sample(:contact)
        text_result = sampler.sample(:text)

        expect(contact_result.category).to eq('contact')
        expect(text_result.category).to eq('text')
      end
    end

    context 'cache expiration' do
      it 'refreshes cache after expiration' do
        sampler.sample(:contact)

        # Fast-forward time past cache expiration
        travel_to(described_class::CACHE_DURATION.from_now + 1.second) do
          expect(AlarmContent).to receive(:contact).and_call_original

          sampler.sample(:contact)
        end
      end
    end

    context 'with empty category' do
      before do
        AlarmContent.destroy_all
      end

      it 'returns nil when no content exists' do
        result = sampler.sample(:contact)
        expect(result).to be_nil
      end
    end
  end

  describe '#preload_all' do
    it 'loads all alarm content categories' do
      expect(AlarmContent).to receive(:contact).once.and_call_original
      expect(AlarmContent).to receive(:text).once.and_call_original

      sampler.preload_all
    end

    it 'caches content for all categories' do
      sampler.preload_all

      expect(sampler.cached_content(:contact)).to be_an(Array)
      expect(sampler.cached_content(:text)).to be_an(Array)
    end

    it 'reduces queries in batch operations' do
      sampler.preload_all

      query_count = count_queries do
        100.times { sampler.sample(:contact) }
      end

      expect(query_count).to eq(0)
    end
  end

  describe '#cached_content' do
    it 'returns nil for non-cached category' do
      expect(sampler.cached_content(:contact)).to be_nil
    end

    it 'returns cached array after preloading' do
      sampler.preload_all

      cached = sampler.cached_content(:contact)

      expect(cached).to be_an(Array)
      expect(cached.length).to eq(2)
    end
  end

  # Helper method to count database queries
  def count_queries
    count = 0
    counter = ->(*, **) { count += 1 }

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      yield
    end

    count
  end
end
