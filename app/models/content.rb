class Content < ApplicationRecord
  enum category: { call: 0, movie: 1, body: 2 }
  validates :body,       presence: true, uniqueness: true, length: { minimum: 2, maximum: 255 }
  validates :category,   presence: true
end
