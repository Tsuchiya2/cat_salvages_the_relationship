class LineGroup < ApplicationRecord
  enum status:    { wait: 0, call: 1 }
  enum set_span:  { random: 0, faster: 1, latter: 2 }

  validates :line_group_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :remind_at,     presence: true
  validates :status,        presence: true
  validates :post_count,    presence: true, numericality: { only_integer: true,
                                                            greater_than_or_equal_to: 0,
                                                            less_than_or_equal_to: 1_000_000_000 }
  validates :member_count,  presence: true, numericality: { only_integer: true,
                                                            greater_than_or_equal_to: 0,
                                                            less_than_or_equal_to: 50 }
  validates :set_span,      presence: true

  scope :remind_wait, -> { wait.where('remind_at <= ?', Date.current) }
  scope :remind_call, -> { call.where('remind_at <= ?', Date.current) }

  def update_line_group_record(count_menbers)
    random_number = if faster?
                      (21..32).to_a.sample
                    elsif latter?
                      (49..60).to_a.sample
                    else
                      (17..60).to_a.sample
                    end
    update!(remind_at: Date.current.since(random_number.days),
            status: :wait, post_count: post_count + 1,
            member_count: count_menbers)
  end
end
