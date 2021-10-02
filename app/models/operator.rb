class Operator < ApplicationRecord
  enum role: { operator: 0, guest: 1 }

  validates :name,  presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true
  validates :role,  presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
