class AlarmContent < ApplicationRecord
  enum category: { contact: 0, free_one: 1, free_two: 2, free_three: 3, text: 4 }
  validates :body,       presence: true, uniqueness: true, length: { in: 2..255 }
  validates :category,   presence: true
end
