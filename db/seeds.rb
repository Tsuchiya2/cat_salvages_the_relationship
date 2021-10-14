# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# 仮seedデータ
Operator.create(name: 'guest',
                email: Rails.application.credentials.guest[:email],
                password: Rails.application.credentials.guest[:password],
                password_confirmation: Rails.application.credentials.guest[:password],
                role: 1) unless Operator.find_by(email: Rails.application.credentials.guest[:email])


unless Content.find_by(body: Rails.application.credentials.content[:movie])
  Content.transaction do
    Content.create(body: 'ニャ〜ニャ〜久しぶりニャ🐱🐾', category: :call)
    Content.create(body: Rails.application.credentials.content[:movie], category: :movie)
    Content.create(body: '聞いたところによると日本にはいろんなお茶会があるらしいニャンね🍵 今度、お茶会ならぬ「ちゅ〜る食べ比べ会」を開催してほしいニャ〜🐾', category: :free)
  end
end

unless AlarmContent.find_by(body: Rails.application.credentials.alarmcontent[:url])
  AlarmContent.transaction do
    AlarmContent.create(body: 'あれ。。。みんニャ忙しい？', category: :contact)
    AlarmContent.create(body: 'こんニャのどうかニャ〜🐱', category: :proposal)
    AlarmContent.create(body: Rails.application.credentials.alarmcontent[:url], category: :url)
    AlarmContent.create(body: '反応ないと寂しいニャ。。。', category: :naive)
    AlarmContent.create(body: 'また近々コールするニャ！！ See you laterニャ🐱🐾', category: :free)
  end
end
