FactoryBot.define do
  factory :content_category do
    sequence(:name) { |n| "Category_#{n}" }
  end
end
