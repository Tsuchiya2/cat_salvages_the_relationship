# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::GroupService do
  let(:adapter) { instance_double(Line::ClientAdapter) }
  let(:service) { described_class.new(adapter) }

  describe '#find_or_create' do
    let(:group_id) { 'GROUP123' }
    let(:member_count) { 5 }

    context 'when group does not exist' do
      it 'creates new group with correct attributes' do
        expect do
          service.find_or_create(group_id, member_count)
        end.to change(LineGroup, :count).by(1)

        group = LineGroup.last
        expect(group.line_group_id).to eq(group_id)
        expect(group.member_count).to eq(member_count)
        expect(group.status).to eq('wait')
        expect(group.remind_at).to eq(Date.current.tomorrow)
      end

      it 'returns created group' do
        group = service.find_or_create(group_id, member_count)

        expect(group).to be_a(LineGroup)
        expect(group.line_group_id).to eq(group_id)
      end
    end

    context 'when group already exists' do
      let!(:existing_group) { create(:line_group, line_group_id: group_id) }

      it 'does not create duplicate group' do
        expect do
          service.find_or_create(group_id, member_count)
        end.not_to change(LineGroup, :count)
      end

      it 'returns existing group' do
        group = service.find_or_create(group_id, member_count)

        expect(group).to eq(existing_group)
      end
    end

    context 'with invalid parameters' do
      it 'returns nil for blank group_id' do
        result = service.find_or_create('', member_count)

        expect(result).to be_nil
      end

      it 'returns nil for member_count < 2' do
        result = service.find_or_create(group_id, 1)

        expect(result).to be_nil
      end

      it 'does not create group for 1-on-1 chats' do
        expect do
          service.find_or_create(group_id, 1)
        end.not_to change(LineGroup, :count)
      end
    end
  end

  describe '#update_record' do
    let(:group_id) { 'GROUP123' }
    let(:member_count) { 5 }
    let!(:line_group) { create(:line_group, line_group_id: group_id, post_count: 10, member_count: 4) }

    context 'when group exists' do
      it 'increments post_count' do
        expect do
          service.update_record(group_id, member_count)
        end.to change { line_group.reload.post_count }.from(10).to(11)
      end

      it 'updates member_count' do
        expect do
          service.update_record(group_id, member_count)
        end.to change { line_group.reload.member_count }.from(4).to(5)
      end
    end

    context 'when group does not exist' do
      it 'does not raise error' do
        expect do
          service.update_record('NONEXISTENT', member_count)
        end.not_to raise_error
      end
    end

    context 'with member_count < 2' do
      it 'does not update group' do
        expect do
          service.update_record(group_id, 1)
        end.not_to(change { line_group.reload.post_count })
      end
    end
  end

  describe '#delete_if_empty' do
    let(:group_id) { 'GROUP123' }
    let!(:line_group) { create(:line_group, line_group_id: group_id) }

    context 'when member_count <= 1' do
      it 'deletes group' do
        expect do
          service.delete_if_empty(group_id, 1)
        end.to change(LineGroup, :count).by(-1)
      end

      it 'handles member_count = 0' do
        expect do
          service.delete_if_empty(group_id, 0)
        end.to change(LineGroup, :count).by(-1)
      end
    end

    context 'when member_count > 1' do
      it 'does not delete group' do
        expect do
          service.delete_if_empty(group_id, 2)
        end.not_to change(LineGroup, :count)
      end
    end

    context 'when group does not exist' do
      it 'does not raise error' do
        expect do
          service.delete_if_empty('NONEXISTENT', 1)
        end.not_to raise_error
      end
    end
  end

  describe '#send_welcome_message' do
    let(:group_id) { 'GROUP123' }

    before do
      allow(adapter).to receive(:push_message)
    end

    context 'with :join message type' do
      it 'sends join welcome message' do
        service.send_welcome_message(group_id, message_type: :join)

        expect(adapter).to have_received(:push_message).with(
          group_id,
          hash_including(
            type: 'text',
            text: match(/加えてくれてありがとうニャ/)
          )
        )
      end
    end

    context 'with :member_joined message type' do
      it 'sends member joined welcome message' do
        service.send_welcome_message(group_id, message_type: :member_joined)

        expect(adapter).to have_received(:push_message).with(
          group_id,
          hash_including(
            type: 'text',
            text: match(/初めまして/)
          )
        )
      end
    end

    context 'with default message type' do
      it 'sends join message by default' do
        service.send_welcome_message(group_id)

        expect(adapter).to have_received(:push_message).with(
          group_id,
          hash_including(
            type: 'text',
            text: match(/加えてくれてありがとうニャ/)
          )
        )
      end
    end
  end
end
