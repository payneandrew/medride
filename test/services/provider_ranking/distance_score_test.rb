require "test_helper"

class ProviderRanking::DistanceScoreTest < ActiveSupport::TestCase
  test "scores closer providers higher than farther ones" do
    ride = rides(:requested_ride) # pickup near Springfield, IL
    near = ProviderRanking::DistanceScore.new(ride, transport_providers(:acme)) # based in Springfield, IL

    far_provider = TransportProvider.create!(name: "Faraway Co", phone: "555-0000", base_lat: 43.0389, base_lng: -87.9065) # Milwaukee, WI
    far = ProviderRanking::DistanceScore.new(ride, far_provider)

    assert near.score > far.score
  end

  test "falls back to a neutral score when either side has no coordinates" do
    ride = rides(:requested_ride)
    provider = TransportProvider.create!(name: "No Location Co", phone: "555-0001")

    distance = ProviderRanking::DistanceScore.new(ride, provider)

    assert_nil distance.miles
    assert_equal ProviderRanking::DistanceScore::DEFAULT_SCORE, distance.score
  end
end
