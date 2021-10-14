class LineGroup < ApplicationRecord
  enum status: { wait: 0, call: 1 }

  validates :line_group_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :remind_at,     presence: true
  validates :status,        presence: true

  scope :remind_wait, -> { wait.where('remind_at <= ?', Date.current) }
  scope :remind_call, -> { call.where('remind_at <= ?', Date.current) }
end
