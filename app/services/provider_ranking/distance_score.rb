module ProviderRanking
  # How far this provider's dispatch base is from the pickup — a proxy for
  # ETA without needing a real routing/traffic API. Smooth decay rather
  # than a hard cutoff: MatchRide already filtered to providers who cover
  # this zip, so nobody here is "too far," they're just relatively closer
  # or farther.
  class DistanceScore
    DECAY_MILES = 10.0 # distance at which the score is roughly halved
    DEFAULT_SCORE = 0.5 # neutral when we can't compute a real distance

    def initialize(ride, transport_provider)
      @ride = ride
      @transport_provider = transport_provider
    end

    def score
      return DEFAULT_SCORE if miles.nil?

      1.0 / (1.0 + miles / DECAY_MILES)
    end

    def miles
      return @miles if defined?(@miles)

      @miles = Geo::Haversine.miles(ride.pickup_lat, ride.pickup_lng, transport_provider.base_lat, transport_provider.base_lng)
    end

    private

    attr_reader :ride, :transport_provider
  end
end
