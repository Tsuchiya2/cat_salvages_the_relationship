namespace :call_notice do
  require './app/lines/events/line_event'
  desc '短いスパンでの働きかけを行う'
  task call_reminds: :environment do
    client = LineEvent.set_line_bot_client

    messages = [{ type: 'text', text: AlarmContent.contact.sample.body },
                { type: 'text', text: AlarmContent.text.sample.body }]

    remaind_groups = LineGroup.remind_call
    remaind_groups.find_each do |group|
      messages.each_with_index do |message, index|
        response = client.push_message(group.line_group_id, message)
        raise "働きかけ#{index + 1}つ目でエラー発生。#{message}" if response.code == '400'
      end
      group.remind_at = Date.current.since((2..5).to_a.sample.days)
      group.save!
    rescue StandardError => e
      error_message = "<CallNotice> 例外:#{e.class}, メッセージ:#{e.message}, バックトレース:#{e.backtrace}"
      LineMailer.error_email(group.line_group_id, error_message).deliver_later
    end
  end
end
