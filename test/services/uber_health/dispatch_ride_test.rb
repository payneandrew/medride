require "test_helper"

class UberHealth::DispatchRideTest < ActiveSupport::TestCase
  test "dispatching a requested ride claims it via Uber Health with an external_ride_id" do
    ride = rides(:requested_ride)
    ride.update!(level_of_service: "rideshare")

    response = UberHealth::DispatchRide.call(ride)

    assert ride.reload.claimed?
    assert_equal "Uber Health", ride.active_claim.transport_provider.name
    assert_equal response.external_ride_id, ride.active_claim.external_ride_id
  end

  test "raises for a level_of_service Uber Health doesn't support" do
    ride = rides(:requested_ride) # wheelchair_van by default fixture value

    assert_raises(UberHealth::Client::UnsupportedLevelOfServiceError) do
      UberHealth::DispatchRide.call(ride)
    end
  end

  test "raises if the ride isn't requested" do
    assert_raises(Ride::InvalidTransition) do
      UberHealth::DispatchRide.call(rides(:claimed_ride))
    end
  end
end
