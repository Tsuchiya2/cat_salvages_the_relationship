class LineGroup < ApplicationRecord
  enum status: { wait: 0, call: 1 }

  validates :line_group_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :remind_at,     presence: true
  validates :status,        presence: true
  validates :post_count,    presence: true, numericality: { only_integer: true,
                                                            greater_than_or_equal_to: 0,
                                                            less_than_or_equal_to: 1_000_000_000 }

  scope :remind_wait, -> { wait.where('remind_at <= ?', Date.current) }
  scope :remind_call, -> { call.where('remind_at <= ?', Date.current) }

  def change_status_to_wait
    random_number = (23..60).to_a.sample
    update!(remind_at: Date.current.since(random_number.days), status: :wait, post_count: post_count + 1)
  end
end
