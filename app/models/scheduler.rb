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
      scheduler(remind_groups, sampler, :call)
    end

    # Send wait reminder messages
    #
    # Sends wake-up messages to LINE groups that are due for 'wait' reminders.
    # Uses Content for message selection with preloading to avoid N+1.
    def wait_notice
      remind_groups = LineGroup.remind_wait
      sampler = initialize_content_sampler
      scheduler(remind_groups, sampler, :wait)
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
      ensure_content_presence!(sampler, %i[contact text])

      [{ type: 'text', text: safe_body(sampler, :contact, CALL_FALLBACK_CONTACT) },
       { type: 'text', text: safe_body(sampler, :text, CALL_FALLBACK_TEXT) }]
    end

    # Build wait reminder messages
    #
    # @param sampler [Line::ContentSampler] Preloaded content sampler
    # @return [Array<Hash>] Array of message hashes for LINE API
    def wait_messages(sampler)
      ensure_content_presence!(sampler, %i[contact free text])

      [{ type: 'text', text: safe_body(sampler, :contact, WAIT_FALLBACK_CONTACT) },
       { type: 'text', text: safe_body(sampler, :free, WAIT_FALLBACK_FREE) },
       { type: 'text', text: safe_body(sampler, :text, WAIT_FALLBACK_TEXT) }]
    end

    # Core scheduler logic
    #
    # Sends messages to each group with retry handling and transaction safety.
    #
    # @param remind_groups [ActiveRecord::Relation] Groups to send messages to
    # @param sampler [Line::ContentSampler, Line::AlarmContentSampler] Preloaded content sampler
    # @param adapter [Line::ClientAdapter] LINE client adapter
    # @param notice_type [Symbol] Type of notice (:call or :wait)
    def scheduler(remind_groups, sampler, notice_type)
      remind_groups.find_each do |group|
        messages = build_messages(sampler, notice_type)

        ActiveRecord::Base.transaction do
          group.remind_at = Date.current.since((1..3).to_a.sample.days)
          group.call!
        end

        Line::ReminderJob.perform_later(group.line_group_id, messages)
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

    def ensure_content_presence!(sampler, categories)
      missing = categories.reject { |category| sampler.available?(category) }
      raise StandardError, "コンテンツ未登録: #{missing.join(', ')}" if missing.any?
    end

    def safe_body(sampler, category, fallback)
      content = sampler.sample(category)
      return content.body if content.respond_to?(:body)

      fallback
    end

    CALL_FALLBACK_CONTACT = '管理者へ連絡お願いします。'.freeze
    CALL_FALLBACK_TEXT = '呼びかけメッセージを用意できなかったニャ…🐱'.freeze
    WAIT_FALLBACK_CONTACT = 'いつでも声をかけてニャ！'.freeze
    WAIT_FALLBACK_FREE = '今日はどんな一日だった？'.freeze
    WAIT_FALLBACK_TEXT = 'もう少し仲良くなりたいニャ🐾'.freeze
  end
end
