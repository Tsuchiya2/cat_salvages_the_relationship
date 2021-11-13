FactoryBot.define do
  factory :line_group do
    sequence(:line_group_id) { |n| "Line_Group_Id:No#{n}" }
    remind_at { Time.current.since(10.days) }
    status { :wait }
  end
end
