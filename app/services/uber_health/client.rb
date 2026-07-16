module UberHealth
  # Fake stand-in for Uber Health's B2B ride-booking API — there's no public
  # sandbox to hit the way HAPI is a real FHIR server, so this simulates the
  # request/response shape rather than calling anything over the network.
  #
  # A real client would authenticate with OAuth2 client-credentials, POST to
  # something like https://api.uber.com/v1/health/rides with pickup/dropoff
  # coordinates and a patient reference, and get back a ride id + an ETA.
  # The point of keeping this behind the same Client/request-response
  # pattern as Fhir::Client is that swapping the fake for the real thing
  # later is a one-file change — nothing else in the app talks to Uber
  # directly.
  class Client
    SUPPORTED_LEVELS_OF_SERVICE = %w[rideshare medical_sedan].freeze

    class UnsupportedLevelOfServiceError < StandardError; end

    def request_ride(ride)
      unless SUPPORTED_LEVELS_OF_SERVICE.include?(ride.level_of_service)
        raise UnsupportedLevelOfServiceError, "Uber Health doesn't offer #{ride.level_of_service}"
      end

      RideResponse.new(
        external_ride_id: "uber-#{SecureRandom.hex(8)}",
        status: "accepted",
        eta_minutes: rand(5..20)
      )
    end
  end
end
