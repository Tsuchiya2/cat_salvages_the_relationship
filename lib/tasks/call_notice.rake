namespace :call_notice do
  require './app/line_bot_classes/manifest'
  desc '短いスパンでの働きかけを行う'
  task call_reminds: :environment do
    client = ClientConfig.set_line_bot_client

    # 送信するメッセージ選定
    contact_message   = { type: 'text', text: AlarmContent.contact.sample.body }
    proposal_message  = { type: 'text', text: AlarmContent.proposal.sample.body }
    url_message       = { type: 'text', text: AlarmContent.url.sample.body }
    naive_message     = { type: 'text', text: AlarmContent.naive.sample.body }
    free_message      = { type: 'text', text: AlarmContent.free.sample.body }

    remaind_groups = LineGroup.remind_call
    remaind_groups.find_each do |group|
      LineGroup.transaction do
        # === 現状だと送信が上手くいかなかった際にtransactionは機能していません ===
        client.push_message(group.line_group_id, contact_message)
        client.push_message(group.line_group_id, proposal_message)
        client.push_message(group.line_group_id, url_message)
        client.push_message(group.line_group_id, naive_message)
        client.push_message(group.line_group_id, free_message)
        group.remind_at = Date.current.since((7..12).to_a.sample.days)
        group.save!
      end
    end
  end
end
