class Operator < ApplicationRecord
  authenticates_with_sorcery!
  enum :role, { operator: 0, guest: 1 }

  validates :name,                    presence: true, length: { in: 2..255 }
  validates :email,                   presence: true, uniqueness: true
  validates :email,                   format: { with: /\A[a-z0-9_-]+@[a-z0-9_-]+\.[a-z0-9_-]+\z/ }
  validates :password,                presence: true
  validates :password,                length: { minimum: 8 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password,                confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation,   presence: true, if: -> { new_record? || changes[:crypted_password] }
  validates :role,                    presence: true

  def mail_notice(access_ip)
    SessionMailer.notice(self, access_ip).deliver_later if lock_expires_at.present?
  end
end
