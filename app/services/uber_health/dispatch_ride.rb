module UberHealth
  # The auto-dispatch path: unlike MatchRide + Ride#claim!, which assume a
  # human provider picks a ride out of the marketplace pool, Uber Health has
  # its own dispatch engine — booking *is* claiming. There's no "eligible
  # providers" step; we ask Uber for a ride and either it accepts or it
  # doesn't.
  class DispatchRide
    def self.call(ride)
      new(ride).call
    end

    def initialize(ride, client: Client.new)
      @ride = ride
      @client = client
    end

    def call
      raise Ride::InvalidTransition, "cannot dispatch a #{ride.status} ride" unless ride.can_claim?

      response = client.request_ride(ride)
      ride.claim!(uber_health_provider, external_ride_id: response.external_ride_id)
      response
    end

    private

    attr_reader :ride, :client

    def uber_health_provider
      TransportProvider.find_by!(name: "Uber Health")
    end
  end
end
