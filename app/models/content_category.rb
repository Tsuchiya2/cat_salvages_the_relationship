class ContentCategory < ApplicationRecord
  has_many :contents
  validates :name, presence: true, length: { maximum: 255 }
end
