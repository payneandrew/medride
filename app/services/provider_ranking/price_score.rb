module ProviderRanking
  # Estimated fare = this provider's base fare + their per-mile rate * the
  # actual trip distance (pickup -> dropoff — not the provider's distance
  # from pickup; that's DistanceScore's job, a different distance entirely).
  # Smooth decay, same shape as DistanceScore, so both map onto a
  # comparable 0.0-1.0 range before RankProviders weights and sums them.
  class PriceScore
    DECAY_DOLLARS = 20.0 # price at which the score is roughly halved
    FALLBACK_TRIP_MILES = 5.0 # used when trip_miles is unknown, so price still reflects this provider's own rate rather than going fully neutral

    def initialize(ride, transport_provider)
      @ride = ride
      @transport_provider = transport_provider
    end

    def estimated_price_cents
      transport_provider.base_fare_cents + (transport_provider.rate_per_mile_cents * trip_miles).round
    end

    def score
      1.0 / (1.0 + (estimated_price_cents / 100.0) / DECAY_DOLLARS)
    end

    private

    attr_reader :ride, :transport_provider

    def trip_miles
      ride.trip_miles || FALLBACK_TRIP_MILES
    end
  end
end
