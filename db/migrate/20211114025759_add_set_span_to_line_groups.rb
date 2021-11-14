class AddSetSpanToLineGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :line_groups, :set_span, :integer, null: false, default: 0
  end
end
