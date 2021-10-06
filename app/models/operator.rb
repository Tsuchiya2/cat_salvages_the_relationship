class Operator < ApplicationRecord
  authenticates_with_sorcery!
  enum role: { operator: 0, guest: 1 }

  validates :name,                    presence: true, length: { minimum: 2, maximum: 255 }
  validates :email,                   presence: true, uniqueness: true
  validates :email,                   format: { with: /\A[a-z0-9_-]+@[a-z0-9_-]+[\\.][a-z0-9_-]+/ }
  validates :password,                presence: true
  validates :password,                length: { minimum: 8 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password,                confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation,   presence: true, if: -> { new_record? || changes[:crypted_password] }
  validates :role,                    presence: true
end
