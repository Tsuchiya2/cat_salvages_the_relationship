FactoryBot.define do
  factory :alarm_content do
    sequence(:body) { |n| "AlarmContent_#{n}" }
    category { :contact }
  end
end
