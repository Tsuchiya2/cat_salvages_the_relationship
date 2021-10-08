FactoryBot.define do
  factory :alarm_content_category do
    sequence(:name) { |n| "AlarmCategory_#{n}" }
  end
end
