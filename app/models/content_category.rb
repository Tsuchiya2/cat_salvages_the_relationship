class ContentCategory < ApplicationRecord
  has_many :contents,   dependent: :destroy
  validates :name,      presence: true, length: { minimum: 2, maximum: 255 }
end
