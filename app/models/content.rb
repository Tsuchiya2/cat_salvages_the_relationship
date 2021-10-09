class Content < ApplicationRecord
  enum category: { call: 0, movie: 1, text: 2 }
  validates :body,       pesence: true, length: { minimum: 2, maximum: 65_535 }
  validates :category,   presence: true
end
