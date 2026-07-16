class RideStatusEvent < ApplicationRecord
  include RideStatus

  belongs_to :ride
  # nil actor means the system made the change (e.g. a vendor webhook), not
  # a coordinator or provider clicking a button.
  belongs_to :actor, polymorphic: true, optional: true

  enum :from_status, RideStatus::VALUES, prefix: true
  enum :to_status, RideStatus::VALUES, prefix: true

  validates :to_status, presence: true
  validates :occurred_at, presence: true

  def actor_label
    actor ? "#{actor.class.name}: #{actor.try(:name) || actor.id}" : "system"
  end
end
