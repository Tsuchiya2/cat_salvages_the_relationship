# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::MemberCounter do
  let(:adapter) { instance_double(Line::ClientAdapter) }
  let(:counter) { described_class.new(adapter) }

  describe '#count' do
    context 'with group event' do
      let(:event) do
        double(
          'GroupEvent',
          source: double(group_id: 'GROUP123', room_id: nil)
        )
      end

      it 'calls get_group_member_count and returns the count' do
        allow(adapter).to receive(:get_group_member_count).with('GROUP123').and_return(5)

        result = counter.count(event)

        expect(result).to eq(5)
        expect(adapter).to have_received(:get_group_member_count).with('GROUP123')
      end

      it 'returns fallback value (2) when API call fails' do
        allow(adapter).to receive(:get_group_member_count).and_raise(StandardError, 'API Error')
        allow(Rails.logger).to receive(:warn)

        result = counter.count(event)

        expect(result).to eq(2)
      end

      it 'logs warning when fallback is used' do
        allow(adapter).to receive(:get_group_member_count).and_raise(StandardError, 'API Error')
        allow(Rails.logger).to receive(:warn)

        counter.count(event)

        expect(Rails.logger).to have_received(:warn).with(/Failed to get member count/)
      end
    end

    context 'with room event' do
      let(:event) do
        double(
          'RoomEvent',
          source: double(group_id: nil, room_id: 'ROOM456')
        )
      end

      it 'calls get_room_member_count and returns the count' do
        allow(adapter).to receive(:get_room_member_count).with('ROOM456').and_return(3)

        result = counter.count(event)

        expect(result).to eq(3)
        expect(adapter).to have_received(:get_room_member_count).with('ROOM456')
      end

      it 'returns fallback value when room API fails' do
        allow(adapter).to receive(:get_room_member_count).and_raise(StandardError)
        allow(Rails.logger).to receive(:warn)

        result = counter.count(event)

        expect(result).to eq(2)
      end
    end

    context 'with 1-on-1 event (no group or room)' do
      let(:event) do
        double(
          'DirectEvent',
          source: double(group_id: nil, room_id: nil)
        )
      end

      it 'returns fallback value without API call' do
        result = counter.count(event)

        expect(result).to eq(2)
      end
    end

    context 'with nil event source' do
      let(:event) { double('NilSource', source: nil) }

      it 'returns fallback value' do
        result = counter.count(event)

        expect(result).to eq(2)
      end
    end

    context 'when event source has blank group_id and room_id' do
      let(:event) do
        double(
          'BlankEvent',
          source: double(group_id: '', room_id: '')
        )
      end

      it 'returns fallback value' do
        allow(adapter).to receive(:get_group_member_count).and_raise(StandardError)
        allow(Rails.logger).to receive(:warn)

        result = counter.count(event)

        expect(result).to eq(2)
      end
    end
  end
end
