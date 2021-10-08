class Content < ApplicationRecord
  belongs_to :content_category
  validates :body,                  presence: true, length: { minimum: 2, maximum: 65_535 }
  validates :content_category_id,   presence: true
end
