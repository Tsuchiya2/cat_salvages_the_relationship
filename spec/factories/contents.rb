FactoryBot.define do
  factory :content do
    sequence(:body) { |n| "Content_#{n}" }
    category { :call }
  end
end
