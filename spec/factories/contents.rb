FactoryBot.define do
  factory :content do
    sequence(:body) { |n| "Content_#{n}" }
    association :content_category
  end
end
