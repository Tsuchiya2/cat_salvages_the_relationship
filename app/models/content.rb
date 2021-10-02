class Content < ApplicationRecord
  belongs_to :content_category
  validates :body, presence: true, length: { maximum: 65_535 }
end
