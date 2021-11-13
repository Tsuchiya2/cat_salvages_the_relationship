class LineGroup < ApplicationRecord
  enum status: { wait: 0, call: 1 }

  validates :line_group_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :remind_at,     presence: true
  validates :status,        presence: true
  validates :post_count,    presence: true, numericality: { only_integer: true,
                                                            greater_than_or_equal_to: 0,
                                                            less_than_or_equal_to: 1_000_000_000 }
  validates :member_count,  presence: true, numericality: { only_integer: true,
                                                            greater_than_or_equal_to: 0,
                                                            less_than_or_equal_to: 50 }

  scope :remind_wait, -> { wait.where('remind_at <= ?', Date.current) }
  scope :remind_call, -> { call.where('remind_at <= ?', Date.current) }

  def change_short_status_by_magicword(count_menbers)
    random_number = (21..32).to_a.sample
    passsed_day = (remind_at - updated_at.to_date).to_int
    update!(remind_at: remind_at + (random_number - passsed_day),
            status: :wait, post_count: post_count + 1,
            member_count: count_menbers)
  end

  def change_long_status_by_magicword(count_menbers)
    random_number = (49..60).to_a.sample
    passsed_day = (remind_at - updated_at.to_date).to_int
    update!(remind_at: remind_at + (random_number - passsed_day),
            status: :wait, post_count: post_count + 1,
            member_count: count_menbers)
  end

  def auto_change_status(count_menbers)
    random_number = (17..50).to_a.sample
    update!(remind_at: Date.current.since(random_number.days),
            status: :wait, post_count: post_count + 1,
            member_count: count_menbers)
  end
end
