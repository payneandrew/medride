class Ride < ApplicationRecord
  include LevelOfService
  include RideStatus

  class InvalidTransition < StandardError; end
  class AlreadyClaimedError < StandardError; end

  belongs_to :patient
  belongs_to :coordinator

  has_many :ride_claims, dependent: :destroy
  has_many :ride_status_events, -> { order(:occurred_at) }, dependent: :destroy

  enum :level_of_service, LevelOfService::VALUES
  enum :status, RideStatus::VALUES

  validates :pickup_address_line1, :pickup_city, :pickup_state, :pickup_zip, presence: true
  validates :dropoff_address_line1, :dropoff_city, :dropoff_state, :dropoff_zip, presence: true
  validates :scheduled_at, presence: true
  validate :level_of_service_is_right_sized

  after_create :log_initial_status_event

  def active_claim
    ride_claims.active.first
  end

  # nil unless both pickup and dropoff were captured with coordinates (i.e.
  # picked via the Places Autocomplete widget, not hand-typed) — see
  # ProviderRanking::PriceScore, which falls back to an estimate when this
  # is unknown rather than requiring it.
  def trip_miles
    Geo::Haversine.miles(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
  end

  # --- Guards ---------------------------------------------------------
  # Kept as separate predicate methods (rather than one big case statement)
  # so the UI can ask "can_claim?" to decide whether to render a button,
  # without needing to attempt (and rescue) the transition itself.
  def can_claim? = requested?
  def can_release? = claimed?
  def can_start? = claimed?
  def can_complete? = in_progress?
  def can_cancel? = requested? || claimed? || in_progress?

  # --- Transitions ------------------------------------------------------

  # The one transition that can race: two providers hitting "claim" on the
  # same requested ride at nearly the same moment both read status:
  # requested and both pass can_claim? in their own request's transaction.
  # Ruby-level guards cannot arbitrate that — only the database can. The
  # unique partial index on ride_claims (ride_id WHERE released_at IS NULL)
  # lets exactly one INSERT succeed; the loser's transaction raises
  # RecordNotUnique, which we translate into AlreadyClaimedError.
  def claim!(transport_provider, actor: transport_provider, external_ride_id: nil)
    raise InvalidTransition, "cannot claim a #{status} ride" unless can_claim?

    transaction do
      ride_claims.create!(transport_provider: transport_provider, claimed_at: Time.current, external_ride_id: external_ride_id)
      transition_to!("claimed", actor: actor)
    end
    true
  rescue ActiveRecord::RecordNotUnique
    raise AlreadyClaimedError, "ride #{id} already has an active claim"
  end

  # Hands the ride back to the marketplace. Note this does not introduce a
  # "released" status value — it returns the ride to "requested" so it's
  # claimable again, exactly like it was before anyone claimed it.
  def release!(actor:)
    raise InvalidTransition, "cannot release a #{status} ride" unless can_release?

    transaction do
      active_claim&.update!(released_at: Time.current)
      transition_to!("requested", actor: actor)
    end
    true
  end

  def start!(actor:)
    raise InvalidTransition, "cannot start a #{status} ride" unless can_start?

    transition_to!("in_progress", actor: actor)
    true
  end

  def complete!(actor:)
    raise InvalidTransition, "cannot complete a #{status} ride" unless can_complete?

    transition_to!("completed", actor: actor)
    true
  end

  def cancel!(actor:)
    raise InvalidTransition, "cannot cancel a #{status} ride" unless can_cancel?

    transaction do
      active_claim&.update!(released_at: Time.current)
      transition_to!("cancelled", actor: actor)
    end
    true
  end

  private

  def level_of_service_is_right_sized
    return if patient.nil? || level_of_service.nil?

    unless RightSizingCheck.call(patient: patient, level_of_service: level_of_service)
      errors.add(:level_of_service, "exceeds what this patient's mobility needs require")
    end
  end

  def transition_to!(new_status, actor:, metadata: {})
    from = status
    update!(status: new_status)
    ride_status_events.create!(
      actor: actor,
      from_status: from,
      to_status: new_status,
      occurred_at: Time.current,
      metadata: metadata
    )
  end

  def log_initial_status_event
    ride_status_events.create!(
      actor: coordinator,
      from_status: nil,
      to_status: status,
      occurred_at: created_at,
      metadata: {}
    )
  end
end
