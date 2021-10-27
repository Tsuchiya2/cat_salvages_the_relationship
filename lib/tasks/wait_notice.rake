namespace :wait_notice do
  require './app/lines/manifest'
  desc '不定期な働きかけを行う'
  task wait_reminds: :environment do
    client = ClientConfig.set_line_bot_client

    messages = [{ type: 'text', text: Content.call.sample.body },
                { type: 'text', text: Content.movie.sample.body },
                { type: 'text', text: Content.free.sample.body }]

    remaind_groups = LineGroup.remind_wait
    remaind_groups.find_each do |group|
      response = ''
      messages.each do |message|
        response = client.push_message(group.line_group_id, message) if response.blank? || response.code == '200'
      end
      group.remind_at = Date.current.since((3..5).to_a.sample.days)
      group.call! if response.code == '200'
    end
  end
end
