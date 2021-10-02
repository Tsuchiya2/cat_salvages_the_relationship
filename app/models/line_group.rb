class LineGroup < ApplicationRecord
  enum status: { wait: 0, call: 1, remaind: 2 }

  validates :line_group_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :remind_at,     presence: true
  validates :status,        presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
end
