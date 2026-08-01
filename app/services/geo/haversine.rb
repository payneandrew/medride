module Geo
  # Great-circle distance between two lat/lng points. Shared by
  # ProviderRanking::DistanceScore (provider base -> pickup, for dispatch
  # proximity) and Ride#trip_miles (pickup -> dropoff, for fare estimation)
  # — two genuinely different distances in a real dispatch system, computed
  # the same way.
  module Haversine
    EARTH_RADIUS_MILES = 3958.8

    def self.miles(lat1, lng1, lat2, lng2)
      return nil if [ lat1, lng1, lat2, lng2 ].any?(&:nil?)

      lat1, lng1, lat2, lng2 = [ lat1, lng1, lat2, lng2 ].map(&:to_f)
      to_rad = ->(deg) { deg * Math::PI / 180 }

      dlat = to_rad.(lat2 - lat1)
      dlng = to_rad.(lng2 - lng1)
      a = Math.sin(dlat / 2)**2 + Math.cos(to_rad.(lat1)) * Math.cos(to_rad.(lat2)) * Math.sin(dlng / 2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      EARTH_RADIUS_MILES * c
    end
  end
end
