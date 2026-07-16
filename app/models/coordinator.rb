class Coordinator < ApplicationRecord
  belongs_to :care_organization
  has_many :rides, dependent: :restrict_with_error

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
