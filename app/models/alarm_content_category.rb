class AlarmContentCategory < ApplicationRecord
  has_many :alarm_contents,   dependent: :destroy
  validates :name,            presence: true, length: { maximum: 255 }
end
