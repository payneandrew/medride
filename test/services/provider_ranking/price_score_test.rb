require "test_helper"

class ProviderRanking::PriceScoreTest < ActiveSupport::TestCase
  test "estimated price is base fare plus rate times the actual trip distance" do
    ride = rides(:requested_ride) # has pickup/dropoff coordinates a few miles apart
    provider = transport_providers(:acme) # base_fare_cents: 500, rate_per_mile_cents: 200

    price = ProviderRanking::PriceScore.new(ride, provider)

    expected_cents = provider.base_fare_cents + (provider.rate_per_mile_cents * ride.trip_miles).round
    assert_equal expected_cents, price.estimated_price_cents
  end

  test "cheaper providers score higher than pricier ones" do
    ride = rides(:requested_ride)
    cheap = ProviderRanking::PriceScore.new(ride, transport_providers(:acme))

    pricey_provider = TransportProvider.create!(name: "Premium Co", phone: "555-0002", base_fare_cents: 5000, rate_per_mile_cents: 1000)
    pricey = ProviderRanking::PriceScore.new(ride, pricey_provider)

    assert cheap.score > pricey.score
  end

  test "falls back to an assumed trip distance when the ride has no coordinates" do
    ride = rides(:claimed_ride) # no pickup/dropoff coordinates in this fixture
    provider = transport_providers(:acme)

    price = ProviderRanking::PriceScore.new(ride, provider)
    expected_cents = provider.base_fare_cents + (provider.rate_per_mile_cents * ProviderRanking::PriceScore::FALLBACK_TRIP_MILES).round

    assert_nil ride.trip_miles
    assert_equal expected_cents, price.estimated_price_cents
  end
end
