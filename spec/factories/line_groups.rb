FactoryBot.define do
  factory :line_group do
    sequence(:line_group_id) { |n| "Line_Group_Id:No#{n}" }
    remid_at Time.current.slince(21.days)
    status { :wait }
  end
end
