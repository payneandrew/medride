require "test_helper"

class RankProvidersTest < ActiveSupport::TestCase
  test "ranks eligible providers best-first by composite score" do
    ride = rides(:requested_ride) # wheelchair_van, pickup zip 62704, has pickup/dropoff coordinates

    # acme (fixture): wheelchair_van capability, covers 62704, based in Springfield IL — close by, cheap.
    far_pricey_provider = TransportProvider.create!(
      name: "Far Pricey Co", phone: "555-0005", service_area: [ "62704" ],
      base_lat: 43.0389, base_lng: -87.9065, # Milwaukee, WI — far from this ride's pickup
      base_fare_cents: 5000, rate_per_mile_cents: 1000
    )
    far_pricey_provider.transport_provider_capabilities.create!(capability: "wheelchair_van")

    results = RankProviders.call(ride)

    assert_equal [ transport_providers(:acme), far_pricey_provider ], results.map(&:transport_provider)
    assert results.first.score > results.last.score
  end

  test "only ranks providers MatchRide considers eligible" do
    ride = rides(:requested_ride)

    results = RankProviders.call(ride)

    refute_includes results.map(&:transport_provider), transport_providers(:beta) # wrong capability/zip
  end
end
