class RideClaim < ApplicationRecord
  belongs_to :ride
  belongs_to :transport_provider

  validates :claimed_at, presence: true

  scope :active, -> { where(released_at: nil) }
end
