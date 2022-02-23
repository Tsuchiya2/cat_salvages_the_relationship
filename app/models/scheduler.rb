class Scheduler
  include ActiveModel::Model
  # modelの単体テストもしくはリクエストテストを実装の際を考えて上記の記載を残しております。

  class << self
    def call_notice
      remaind_groups = LineGroup.remind_call
      messages = call_messages
      client = CatLineBot.line_client_config

      scheduler(remaind_groups, messages, client)
    end

    def wait_notice
      remaind_groups = LineGroup.remind_wait
      messages = wait_messages
      client = CatLineBot.line_client_config

      scheduler(remaind_groups, messages, client)
    end

    def call_messages
      [{ type: 'text', text: AlarmContent.contact.sample.body },
       { type: 'text', text: AlarmContent.text.sample.body }]
    end

    def wait_messages
      [{ type: 'text', text: Content.contact.sample.body },
       { type: 'text', text: Content.free.sample.body },
       { type: 'text', text: Content.text.sample.body }]
    end

    def scheduler(remaind_groups, messages, client)
      remaind_groups.find_each do |group|
        messages.each_with_index do |message, index|
          response = client.push_message(group.line_group_id, message)
          raise "働きかけ#{index + 1}つ目でエラー発生。#{message}" if response.code == '400'
        end
        group.remind_at = Date.current.since((1..3).to_a.sample.days)
        group.call!
      rescue StandardError => e
        report_scheduler_errors(e, group)
      end
    end

    def report_scheduler_errors(e, group)
      error_message = "<WaitNotice> 例外:#{e.class}, メッセージ:#{e.message}, バックトレース:#{e.backtrace}"
      LineMailer.error_email(group.line_group_id, error_message).deliver_later
    end
  end
end
