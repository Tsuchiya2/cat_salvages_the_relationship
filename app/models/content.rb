class Content < ApplicationRecord
  enum :category, { contact: 0, free: 1, text: 2 }
  validates :body,       presence: true, uniqueness: true, length: { in: 2..255 }
  validates :category,   presence: true
end
