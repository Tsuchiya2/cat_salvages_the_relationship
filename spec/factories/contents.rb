FactoryBot.define do
  factory :content do
    sequence(:body) { |n| "Content_#{n}" }
    category { :contact }
  end
end
