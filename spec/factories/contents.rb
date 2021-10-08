FactoryBot.define do
  factory :content do
    body { 'Content' }
    association :content_category
  end
end
