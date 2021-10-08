FactoryBot.define do
  factory :alarm_content do
    sequence(:body) { |n| "AlarmContent_#{n}" }
    association :alarm_content_category
  end
end
