# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::EventProcessor do
  let(:adapter) { instance_double(Line::ClientAdapter) }
  let(:member_counter) { instance_double(Line::MemberCounter) }
  let(:group_service) { instance_double(Line::GroupService) }
  let(:command_handler) { instance_double(Line::CommandHandler) }
  let(:one_on_one_handler) { instance_double(Line::OneOnOneHandler) }

  let(:processor) do
    described_class.new(
      adapter: adapter,
      member_counter: member_counter,
      group_service: group_service,
      command_handler: command_handler,
      one_on_one_handler: one_on_one_handler
    )
  end

  # Stub credentials for ApplicationMailer
  before do
    stub_line_credentials
    stub_const('Line::Bot::Event::Message', Class.new)
    stub_const('Line::Bot::Event::Join', Class.new)
    stub_const('Line::Bot::Event::Leave', Class.new)
    stub_const('Line::Bot::Event::MemberJoined', Class.new)
    stub_const('Line::Bot::Event::MemberLeft', Class.new)
  end

  describe '#process' do
    let(:group_id) { 'GROUP123' }
    let(:member_count) { 5 }

    # Create mock event that responds correctly to case/when checks
    let(:message_event) do
      double(
        'Message Event',
        class: Line::Bot::Event::Message,
        timestamp: Time.current.to_i * 1000,
        source: double(group_id: group_id, room_id: nil),
        message: double(id: 'MSG123', text: 'Hello'),
        reply_token: 'REPLY123'
      ).tap do |event|
        # Make case/when work by implementing ===
        allow(Line::Bot::Event::Message).to receive(:===).with(event).and_return(true)
        allow(Line::Bot::Event::Join).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::MemberJoined).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::Leave).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::MemberLeft).to receive(:===).with(event).and_return(false)
        # Handle case/when matching
        allow(event).to receive(:kind_of?).with(Line::Bot::Event::Message).and_return(true)
      end
    end

    let(:join_event) do
      double(
        'Join Event',
        class: Line::Bot::Event::Join,
        timestamp: Time.current.to_i * 1000,
        source: double(group_id: group_id, room_id: nil),
        message: nil,
        reply_token: 'REPLY123'
      ).tap do |event|
        allow(Line::Bot::Event::Message).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::Join).to receive(:===).with(event).and_return(true)
        allow(Line::Bot::Event::MemberJoined).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::Leave).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::MemberLeft).to receive(:===).with(event).and_return(false)
      end
    end

    let(:member_joined_event) do
      double(
        'Member Joined Event',
        class: Line::Bot::Event::MemberJoined,
        timestamp: Time.current.to_i * 1000,
        source: double(group_id: group_id, room_id: nil),
        message: nil,
        reply_token: 'REPLY123'
      ).tap do |event|
        allow(Line::Bot::Event::Message).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::Join).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::MemberJoined).to receive(:===).with(event).and_return(true)
        allow(Line::Bot::Event::Leave).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::MemberLeft).to receive(:===).with(event).and_return(false)
      end
    end

    let(:leave_event) do
      double(
        'Leave Event',
        class: Line::Bot::Event::Leave,
        timestamp: Time.current.to_i * 1000,
        source: double(group_id: group_id, room_id: nil),
        message: nil,
        reply_token: 'REPLY123'
      ).tap do |event|
        allow(Line::Bot::Event::Message).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::Join).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::MemberJoined).to receive(:===).with(event).and_return(false)
        allow(Line::Bot::Event::Leave).to receive(:===).with(event).and_return(true)
        allow(Line::Bot::Event::MemberLeft).to receive(:===).with(event).and_return(false)
      end
    end

    before do
      allow(member_counter).to receive(:count).and_return(member_count)
      allow(PrometheusMetrics).to receive(:track_webhook_duration)
      allow(PrometheusMetrics).to receive(:track_event_success)
      allow(PrometheusMetrics).to receive(:track_event_failure)
    end

    context 'with message events' do
      before do
        allow(command_handler).to receive(:handle_removal)
        allow(command_handler).to receive(:handle_span_setting)
        allow(group_service).to receive(:update_record)
      end

      it 'processes message event successfully' do
        processor.process([message_event])

        expect(command_handler).to have_received(:handle_removal).with(message_event, group_id)
        expect(command_handler).to have_received(:handle_span_setting).with(message_event, group_id)
        expect(group_service).to have_received(:update_record).with(group_id, member_count)
      end

      it 'tracks metrics for successful processing' do
        processor.process([message_event])

        expect(PrometheusMetrics).to have_received(:track_webhook_duration)
        expect(PrometheusMetrics).to have_received(:track_event_success).with(message_event)
      end

      it 'handles 1-on-1 messages separately' do
        one_on_one_event = double(
          'One-on-One Message Event',
          class: Line::Bot::Event::Message,
          timestamp: (Time.current.to_i + 1) * 1000,
          source: double(group_id: nil, room_id: nil),
          message: double(id: 'MSG456', text: 'Hi'),
          reply_token: 'REPLY456'
        ).tap do |event|
          allow(event).to receive(:kind_of?).with(Line::Bot::Event::Message).and_return(true)
        end

        allow(one_on_one_handler).to receive(:handle)

        processor.process([one_on_one_event])

        expect(one_on_one_handler).to have_received(:handle).with(one_on_one_event)
        expect(command_handler).not_to have_received(:handle_removal)
      end
    end

    context 'with join events' do
      before do
        allow(group_service).to receive(:find_or_create)
        allow(group_service).to receive(:send_welcome_message)
      end

      it 'processes join event successfully' do
        processor.process([join_event])

        expect(group_service).to have_received(:find_or_create).with(group_id, member_count)
        expect(group_service).to have_received(:send_welcome_message).with(group_id, message_type: :join)
      end

      it 'processes member joined event with correct message type' do
        allow(group_service).to receive(:send_welcome_message)

        processor.process([member_joined_event])

        expect(group_service).to have_received(:send_welcome_message).with(group_id, message_type: :member_joined)
      end
    end

    context 'with leave events' do
      before do
        allow(group_service).to receive(:delete_if_empty)
      end

      it 'processes leave event successfully' do
        processor.process([leave_event])

        expect(group_service).to have_received(:delete_if_empty).with(group_id, member_count)
      end
    end

    context 'with error handling' do
      before do
        allow(command_handler).to receive(:handle_removal)
        allow(command_handler).to receive(:handle_span_setting)
        allow(group_service).to receive(:update_record).and_raise(StandardError, 'Database error')
        allow(Rails.logger).to receive(:error)
        allow(LineMailer).to receive(:error_email).and_return(double(deliver_later: true))
      end

      it 'handles errors without stopping batch processing' do
        second_event = double(
          'Second Message Event',
          class: Line::Bot::Event::Message,
          timestamp: (Time.current.to_i + 1) * 1000,
          source: double(group_id: 'GROUP456', room_id: nil),
          message: double(id: 'MSG789', text: 'Test'),
          reply_token: 'REPLY789'
        ).tap do |event|
          allow(event).to receive(:kind_of?).with(Line::Bot::Event::Message).and_return(true)
        end

        allow(group_service).to receive(:update_record).with('GROUP456', anything).and_return(true)

        processor.process([message_event, second_event])

        expect(PrometheusMetrics).to have_received(:track_event_failure).with(message_event, kind_of(StandardError))
        expect(PrometheusMetrics).to have_received(:track_event_success).with(second_event)
      end

      it 'sends error email on failure' do
        processor.process([message_event])

        expect(LineMailer).to have_received(:error_email).with(group_id, kind_of(String))
      end

      it 'logs sanitized error message' do
        processor.process([message_event])

        expect(Rails.logger).to have_received(:error)
      end
    end

    context 'with timeout protection' do
      it 'enforces 8-second timeout' do
        allow(command_handler).to receive(:handle_removal)
        allow(command_handler).to receive(:handle_span_setting)
        allow(group_service).to receive(:update_record) { sleep 10 }

        expect do
          processor.process([message_event])
        end.to raise_error(Timeout::Error)
      end

      it 'logs timeout error' do
        allow(command_handler).to receive(:handle_removal)
        allow(command_handler).to receive(:handle_span_setting)
        allow(group_service).to receive(:update_record) { sleep 10 }
        allow(Rails.logger).to receive(:error)

        begin
          processor.process([message_event])
        rescue Timeout::Error
          # Expected
        end

        expect(Rails.logger).to have_received(:error).with(/timeout/i)
      end
    end

    context 'with idempotency tracking' do
      before do
        allow(command_handler).to receive(:handle_removal)
        allow(command_handler).to receive(:handle_span_setting)
        allow(group_service).to receive(:update_record)
      end

      it 'prevents duplicate processing of same event' do
        processor.process([message_event])
        processor.process([message_event])

        expect(group_service).to have_received(:update_record).once
      end
    end

    context 'with transaction management' do
      before do
        allow(command_handler).to receive(:handle_removal)
        allow(command_handler).to receive(:handle_span_setting)
        allow(group_service).to receive(:update_record)
      end

      it 'wraps event processing in transaction' do
        expect(ActiveRecord::Base).to receive(:transaction).and_call_original

        processor.process([message_event])
      end

      it 'rolls back transaction on error' do
        allow(group_service).to receive(:update_record).and_raise(StandardError, 'Error')
        allow(Rails.logger).to receive(:error)
        allow(LineMailer).to receive(:error_email).and_return(double(deliver_later: true))

        expect do
          processor.process([message_event])
        end.not_to change(LineGroup, :count)
      end
    end
  end
end
