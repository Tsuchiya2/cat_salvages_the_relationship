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

Operator.create(name: 'operator',
                email: Rails.application.credentials.operator[:email],
                password: Rails.application.credentials.operator[:password],
                password_confirmation: Rails.application.credentials.operator[:password],
                role: 0) unless Operator.find_by(email: Rails.application.credentials.operator[:email])

unless Content.find_by(body: Rails.application.credentials.content[:movie])
  Content.transaction do
    Content.create(body: 'ニャ〜ニャ〜久しぶりニャ🐱🐾', category: :contact)
    Content.create(body: Rails.application.credentials.content[:movie], category: :free)
    Content.create(body: '再来週あたりでご飯に行かなニャい？🐱🐾', category: :text)
  end
end

unless AlarmContent.find_by(body: Rails.application.credentials.alarmcontent[:url])
  AlarmContent.transaction do
    AlarmContent.create(body: 'みんな忙しいニャ？😥', category: :contact)
    AlarmContent.create(body: Rails.application.credentials.alarmcontent[:url], category: :text)
  end
end
