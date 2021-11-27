namespace :wait_notice do
  desc '不定期な働きかけを行う'
  task wait_reminds: :environment do
    include CatLineBot
    client = set_client

    messages = [{ type: 'text', text: Content.contact.sample.body },
                { type: 'text', text: Content.free.sample.body },
                { type: 'text', text: Content.text.sample.body }]

    remaind_groups = LineGroup.remind_wait
    remaind_groups.find_each do |group|
      messages.each_with_index do |message, index|
        response = client.push_message(group.line_group_id, message)
        raise "働きかけ#{index + 1}つ目でエラー発生。#{message}" if response.code == '400'
      end
      group.remind_at = Date.current.since((1..3).to_a.sample.days)
      group.call!
    rescue StandardError => e
      error_message = "<WaitNotice> 例外:#{e.class}, メッセージ:#{e.message}, バックトレース:#{e.backtrace}"
      LineMailer.error_email(group.line_group_id, error_message).deliver_later
    end
  end
end
