namespace :wait_notice do
  require './app/line_bot_classes/manifest'
  desc '不定期な働きかけを行う'
  task wait_contents: :environment do
    client = ClientConfig.set_line_bot_client

    # 送信するメッセージ選定
    call_message  = { type: 'text', text: Content.call.sample.body }
    movie_message = { type: 'text', text: Content.movie.sample.body }
    free_message  = { type: 'text', text: Content.free.sample.body }

    remaind_groups = LineGroup.remind_wait
    remaind_groups.find_each do |group|
      LineGroup.transaction do
        # === 現状だと送信が上手くいかなかった際にtransactionは機能していません ===
        client.push_message(group.line_group_id, call_message)
        client.push_message(group.line_group_id, movie_message)
        client.push_message(group.line_group_id, free_message)
        group.remind_at = Date.current.since((3..5).to_a.sample.days)
        group.call!
      end
    end
  end
end
