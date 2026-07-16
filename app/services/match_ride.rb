# Given a ride, finds TransportProviders eligible to serve it: their
# service_area covers the pickup zip AND they have the capability matching
# the ride's level_of_service.
class MatchRide
  def self.call(ride)
    new(ride).call
  end

  def initialize(ride)
    @ride = ride
  end

  def call
    TransportProvider
      .joins(:transport_provider_capabilities)
      .where(transport_provider_capabilities: { capability: ride.level_of_service })
      .where("? = ANY(service_area)", ride.pickup_zip)
      .distinct
  end

  private

  attr_reader :ride
end
