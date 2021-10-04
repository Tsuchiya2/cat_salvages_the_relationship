class Operator < ApplicationRecord
  authenticates_with_sorcery!
  enum role: { operator: 0, guest: 1 }

  validates :name,  presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 3 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:crypted_password] }
  validates :role,  presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
