require "test_helper"

class MatchRideTest < ActiveSupport::TestCase
  test "matches providers whose service area covers the pickup zip and who have the right capability" do
    matches = MatchRide.call(rides(:requested_ride))

    assert_equal [ transport_providers(:acme) ], matches.to_a
  end

  test "excludes providers outside the pickup zip even with the right capability" do
    # beta has bls_ambulance, not wheelchair_van, and doesn't cover 62704 anyway
    refute_includes MatchRide.call(rides(:requested_ride)), transport_providers(:beta)
  end
end
