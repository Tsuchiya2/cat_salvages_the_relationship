class ContentCategory < ApplicationRecord
  has_many :contents,   dependent: :destroy
  validates :name,      presence: true, length: { maximum: 255 }
end
