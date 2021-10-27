class AddMemberCountToLineGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :line_groups, :member_count, :integer, null: false, default: 0
  end
end
