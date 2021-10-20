class Feedback < ApplicationRecord
  validates :text, presence: true, length: { in: 100..300 }
end
