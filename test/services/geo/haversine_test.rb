require "test_helper"

class Geo::HaversineTest < ActiveSupport::TestCase
  test "computes a plausible real-world distance" do
    # Springfield, IL to Milwaukee, WI is roughly 240 miles as the crow flies.
    miles = Geo::Haversine.miles(39.7817, -89.6501, 43.0389, -87.9065)

    assert_in_delta 240, miles, 15
  end

  test "is zero for the same point" do
    assert_in_delta 0, Geo::Haversine.miles(39.78, -89.65, 39.78, -89.65), 0.001
  end

  test "returns nil if any coordinate is missing" do
    assert_nil Geo::Haversine.miles(nil, -89.65, 43.03, -87.90)
    assert_nil Geo::Haversine.miles(39.78, nil, 43.03, -87.90)
  end
end
