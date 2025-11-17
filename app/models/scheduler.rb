# Scheduler for sending scheduled LINE messages
#
# Responsible for sending reminder messages to LINE groups at scheduled times.
# Uses modern LINE SDK adapter with retry handling for reliability.
#
# @example Usage (via whenever gem)
#   Scheduler.call_notice  # Send alarm messages to groups in 'call' status
#   Scheduler.wait_notice  # Send wake-up messages to groups in 'wait' status
class Scheduler
  include ActiveModel::Model

  class << self
    # Send call reminder messages
    #
    # Sends alarm messages to LINE groups that are due for 'call' reminders.
    # Uses AlarmContent for message selection with preloading to avoid N+1.
    def call_notice
      remind_groups = LineGroup.remind_call
      sampler = initialize_alarm_sampler
      adapter = Line::ClientProvider.client

      scheduler(remind_groups, sampler, adapter, :call)
    end

    # Send wait reminder messages
    #
    # Sends wake-up messages to LINE groups that are due for 'wait' reminders.
    # Uses Content for message selection with preloading to avoid N+1.
    def wait_notice
      remind_groups = LineGroup.remind_wait
      sampler = initialize_content_sampler
      adapter = Line::ClientProvider.client

      scheduler(remind_groups, sampler, adapter, :wait)
    end

    # Initialize alarm content sampler
    #
    # Preloads all alarm content categories to avoid N+1 queries.
    #
    # @return [Line::AlarmContentSampler] Preloaded sampler
    def initialize_alarm_sampler
      sampler = Line::AlarmContentSampler.new
      sampler.preload_all
      sampler
    end

    # Initialize content sampler
    #
    # Preloads all content categories to avoid N+1 queries.
    #
    # @return [Line::ContentSampler] Preloaded sampler
    def initialize_content_sampler
      sampler = Line::ContentSampler.new
      sampler.preload_all
      sampler
    end

    # Build call reminder messages
    #
    # @param sampler [Line::AlarmContentSampler] Preloaded content sampler
    # @return [Array<Hash>] Array of message hashes for LINE API
    def call_messages(sampler)
      [{ type: 'text', text: sampler.sample(:contact).body },
       { type: 'text', text: sampler.sample(:text).body }]
    end

    # Build wait reminder messages
    #
    # @param sampler [Line::ContentSampler] Preloaded content sampler
    # @return [Array<Hash>] Array of message hashes for LINE API
    def wait_messages(sampler)
      [{ type: 'text', text: sampler.sample(:contact).body },
       { type: 'text', text: sampler.sample(:free).body },
       { type: 'text', text: sampler.sample(:text).body }]
    end

    # Core scheduler logic
    #
    # Sends messages to each group with retry handling and transaction safety.
    #
    # @param remind_groups [ActiveRecord::Relation] Groups to send messages to
    # @param sampler [Line::ContentSampler, Line::AlarmContentSampler] Preloaded content sampler
    # @param adapter [Line::ClientAdapter] LINE client adapter
    # @param notice_type [Symbol] Type of notice (:call or :wait)
    def scheduler(remind_groups, sampler, adapter, notice_type)
      retry_handler = Resilience::RetryHandler.new(max_attempts: 3)

      remind_groups.find_each do |group|
        ActiveRecord::Base.transaction do
          messages = build_messages(sampler, notice_type)

          messages.each_with_index do |message, index|
            retry_handler.call do
              response = adapter.push_message(group.line_group_id, message)
              raise "働きかけ#{index + 1}つ目でエラー発生。#{message}" if response.code == '400'

              PrometheusMetrics.track_message_send('success')
            end
          end

          group.remind_at = Date.current.since((1..3).to_a.sample.days)
          group.call!
        end
      rescue StandardError => e
        report_scheduler_errors(e, group)
        PrometheusMetrics.track_message_send('error')
      end
    end

    # Build messages based on notice type
    #
    # @param sampler [Line::ContentSampler, Line::AlarmContentSampler] Content sampler
    # @param notice_type [Symbol] Type of notice (:call or :wait)
    # @return [Array<Hash>] Array of message hashes
    def build_messages(sampler, notice_type)
      case notice_type
      when :call
        call_messages(sampler)
      when :wait
        wait_messages(sampler)
      else
        raise ArgumentError, "Unknown notice type: #{notice_type}"
      end
    end

    # Report scheduler errors
    #
    # Sends error notification email with sanitized error details.
    #
    # @param exception [StandardError] The error that occurred
    # @param group [LineGroup] The group being processed when error occurred
    def report_scheduler_errors(exception, group)
      sanitizer = ErrorHandling::MessageSanitizer.new
      error_message = sanitizer.format_error(exception, 'Scheduler')
      LineMailer.error_email(group.line_group_id, error_message).deliver_later
    end
  end
end
