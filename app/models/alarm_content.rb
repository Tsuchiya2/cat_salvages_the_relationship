class AlarmContent < ApplicationRecord
  enum :category, { contact: 0, text: 1 }
  validates :body,       presence: true, uniqueness: true, length: { in: 2..255 }
  validates :category,   presence: true
end
