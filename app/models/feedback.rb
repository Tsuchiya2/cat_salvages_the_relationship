class Feedback < ApplicationRecord
  validates :text, presence: true, length: { in: 30..500 }
end
