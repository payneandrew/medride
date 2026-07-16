module UberHealth
  # Uber's own status vocabulary doesn't match ours — this is the
  # adapter/anti-corruption boundary. "arriving" has no equivalent in our
  # state machine (a claimed ride doesn't distinguish "driver en route to
  # pickup" from "claimed"), so it intentionally maps to nil: recognized,
  # acknowledged, but no transition applies.
  class StatusTranslator
    STATUS_MAP = {
      "trip_started" => "in_progress",
      "trip_completed" => "completed",
      "canceled" => "cancelled"
    }.freeze

    def self.call(uber_status)
      STATUS_MAP[uber_status]
    end
  end
end
