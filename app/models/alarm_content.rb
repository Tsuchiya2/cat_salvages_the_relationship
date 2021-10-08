class AlarmContent < ApplicationRecord
  belongs_to :alarm_content_category
  validates :body,                        presence: true, length: { minimum: 2, maximum: 65_535 }
  validates :alarm_content_category_id,   presence: true
end
