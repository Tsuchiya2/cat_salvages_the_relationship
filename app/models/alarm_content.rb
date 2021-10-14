class AlarmContent < ApplicationRecord
  enum category: { contact: 0, proposal: 1, url: 2, naive: 3, free: 4 }
  validates :body,       presence: true, uniqueness: true, length: { minimum: 2, maximum: 255 }
  validates :category,   presence: true
end
