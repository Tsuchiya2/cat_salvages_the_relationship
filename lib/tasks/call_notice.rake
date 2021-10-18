namespace :call_notice do
  require './app/line_bot_classes/manifest'
  desc '短いスパンでの働きかけを行う'
  task call_reminds: :environment do
    client = ClientConfig.set_line_bot_client

    messages = [{ type: 'text', text: Alarmcontent.contact.sample.body },
                { type: 'text', text: AlarmContent.proposal.sample.body },
                { type: 'text', text: AlarmContent.url.sample.body },
                { type: 'text', text: AlarmContent.naive.sample.body },
                { type: 'text', text: AlarmContent.free.sample.body }]

    remaind_groups = LineGroup.remind_call
    remaind_groups.find_each do |group|
      response = ''
      messages.each do |message|
        response = client.push_message(group.line_group_id, message) if response.code != '400'
      end
      group.remind_at = Date.current.since((7..12).to_a.sample.days)
      group.save! if response.code != '400'
    end
  end
end
