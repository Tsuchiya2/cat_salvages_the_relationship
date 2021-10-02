class AlarmContent < ApplicationRecord
  belongs_to :alarm_content_category
  validates :body, presence: true, length: { maximum: 65_535 }
end
