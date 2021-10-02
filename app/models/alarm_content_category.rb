class AlarmContentCategory < ApplicationRecord
  has_many :alarm_contents
  validates :name, presence: true, length: { maximum: 255 }
end
