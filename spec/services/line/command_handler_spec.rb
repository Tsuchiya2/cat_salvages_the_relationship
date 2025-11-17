# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::CommandHandler do
  let(:adapter) { instance_double(Line::ClientAdapter) }
  let(:handler) { described_class.new(adapter) }

  describe '#handle_removal' do
    let(:group_id) { 'GROUP123' }

    context 'with removal command' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: described_class::REMOVAL_COMMAND),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      before do
        allow(adapter).to receive(:leave_group)
      end

      it 'leaves group when in group context' do
        handler.handle_removal(event, group_id)

        expect(adapter).to have_received(:leave_group).with(group_id)
      end
    end

    context 'with removal command in room' do
      let(:room_id) { 'ROOM123' }
      let(:event) do
        double(
          'Message Event',
          message: double(text: described_class::REMOVAL_COMMAND),
          source: double(group_id: nil, room_id: room_id)
        )
      end

      before do
        allow(adapter).to receive(:leave_room)
      end

      it 'leaves room when in room context' do
        handler.handle_removal(event, room_id)

        expect(adapter).to have_received(:leave_room).with(room_id)
      end
    end

    context 'without removal command' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: 'Hello'),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      before do
        allow(adapter).to receive(:leave_group)
      end

      it 'does not leave group' do
        handler.handle_removal(event, group_id)

        expect(adapter).not_to have_received(:leave_group)
      end
    end
  end

  describe '#handle_span_setting' do
    let(:group_id) { 'GROUP123' }
    let!(:line_group) { create(:line_group, line_group_id: group_id, set_span: :random) }

    before do
      allow(adapter).to receive(:push_message)
    end

    context 'with faster command' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: described_class::SPAN_FASTER),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      it 'updates set_span to faster' do
        expect do
          handler.handle_span_setting(event, group_id)
        end.to change { line_group.reload.set_span }.from('random').to('faster')
      end

      it 'sends confirmation message' do
        handler.handle_span_setting(event, group_id)

        expect(adapter).to have_received(:push_message).with(
          group_id,
          hash_including(
            type: 'text',
            text: match(/了解ニャ/)
          )
        )
      end
    end

    context 'with latter command' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: described_class::SPAN_LATTER),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      it 'updates set_span to latter' do
        expect do
          handler.handle_span_setting(event, group_id)
        end.to change { line_group.reload.set_span }.from('random').to('latter')
      end
    end

    context 'with default command' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: described_class::SPAN_DEFAULT),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      before do
        line_group.update!(set_span: :faster)
      end

      it 'updates set_span to random' do
        expect do
          handler.handle_span_setting(event, group_id)
        end.to change { line_group.reload.set_span }.from('faster').to('random')
      end
    end

    context 'without span command' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: 'Hello'),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      it 'does not update set_span' do
        expect do
          handler.handle_span_setting(event, group_id)
        end.not_to change { line_group.reload.set_span }
      end

      it 'does not send confirmation' do
        handler.handle_span_setting(event, group_id)

        expect(adapter).not_to have_received(:push_message)
      end
    end

    context 'when group does not exist' do
      let(:event) do
        double(
          'Message Event',
          message: double(text: described_class::SPAN_FASTER),
          source: double(group_id: group_id, room_id: nil)
        )
      end

      it 'does not raise error' do
        expect do
          handler.handle_span_setting(event, 'NONEXISTENT')
        end.not_to raise_error
      end
    end
  end

  describe '#span_command?' do
    it 'returns true for faster command' do
      expect(handler.span_command?(described_class::SPAN_FASTER)).to be true
    end

    it 'returns true for latter command' do
      expect(handler.span_command?(described_class::SPAN_LATTER)).to be true
    end

    it 'returns true for default command' do
      expect(handler.span_command?(described_class::SPAN_DEFAULT)).to be true
    end

    it 'returns false for other text' do
      expect(handler.span_command?('Hello')).to be false
    end

    it 'returns false for nil' do
      expect(handler.span_command?(nil)).to be false
    end
  end
end
