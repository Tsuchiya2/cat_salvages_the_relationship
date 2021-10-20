class Feedback < ApplicationRecord
  validates :text, presence: true, length: { minimum: 100, maximum: 300 }
end
