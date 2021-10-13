namespace :irregular_notice do
  require './app/line_bot_classes/manifest'
  desc '不定期な働きかけを行う'
  task post_contents: :environment do
    client = ClientConfig.set_line_bot_client

    # 送信するメッセージ選定
    call_message  = { type: 'text', text: Content.call.sample.body }
    movie_message = { type: 'text', text: Content.movie.sample.body }
    body_message  = { type: 'text', text: Content.body.sample.body }

    remaind_groups = LineGroup.remind_today
    remaind_groups.find_each do |group|
      client.push_message(group.line_group_id, call_message)
      client.push_message(group.line_group_id, movie_message)
      client.push_message(group.line_group_id, body_message)
      group.remind_at = Date.current.since((2..5).to_a.sample.days)
      group.call!
    end
  end
end
