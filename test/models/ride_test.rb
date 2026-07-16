require "test_helper"

class RideTest < ActiveSupport::TestCase
  test "requested ride can be claimed" do
    ride = rides(:requested_ride)
    provider = transport_providers(:acme)

    assert ride.can_claim?
    assert ride.claim!(provider)

    assert_equal "claimed", ride.status
    assert_equal provider, ride.active_claim.transport_provider
  end

  test "claiming a ride that is not requested raises and leaves state untouched" do
    ride = rides(:claimed_ride)
    provider = transport_providers(:beta)

    assert_not ride.can_claim?
    assert_raises(Ride::InvalidTransition) { ride.claim!(provider) }
    assert_equal "claimed", ride.reload.status
  end

  test "claiming an already-claimed ride raises AlreadyClaimedError via the db constraint" do
    ride = rides(:claimed_ride)
    other_provider = transport_providers(:beta)

    # Force past the Ruby-level guard to prove the database unique index is
    # what actually stops the double claim, not just can_claim?.
    ride.define_singleton_method(:can_claim?) { true }

    assert_raises(Ride::AlreadyClaimedError) { ride.claim!(other_provider) }
    assert_equal 1, RideClaim.where(ride: ride, released_at: nil).count
  end

  test "claimed ride can be released back to requested" do
    ride = rides(:claimed_ride)
    coordinator = coordinators(:jane)

    assert ride.can_release?
    assert ride.release!(actor: coordinator)

    assert_equal "requested", ride.status
    assert_nil ride.active_claim
    assert_not_nil ride_claims(:acme_active_claim).reload.released_at
  end

  test "releasing a ride that has no active claim raises" do
    ride = rides(:requested_ride)
    assert_not ride.can_release?
    assert_raises(Ride::InvalidTransition) { ride.release!(actor: coordinators(:jane)) }
  end

  test "claimed ride can start" do
    ride = rides(:claimed_ride)
    provider = transport_providers(:acme)

    assert ride.start!(actor: provider)
    assert_equal "in_progress", ride.status
  end

  test "requested ride cannot start" do
    ride = rides(:requested_ride)
    assert_not ride.can_start?
    assert_raises(Ride::InvalidTransition) { ride.start!(actor: coordinators(:jane)) }
  end

  test "in_progress ride can complete" do
    ride = rides(:in_progress_ride)
    provider = transport_providers(:acme)

    assert ride.complete!(actor: provider)
    assert_equal "completed", ride.status
  end

  test "completed ride cannot be cancelled" do
    ride = rides(:completed_ride)
    assert_not ride.can_cancel?
    assert_raises(Ride::InvalidTransition) { ride.cancel!(actor: coordinators(:jane)) }
  end

  test "requested, claimed, and in_progress rides can all be cancelled" do
    [ rides(:requested_ride), rides(:claimed_ride), rides(:in_progress_ride) ].each do |ride|
      assert ride.can_cancel?
      assert ride.cancel!(actor: coordinators(:jane))
      assert_equal "cancelled", ride.status
    end
  end

  test "cancelling a claimed ride releases its active claim" do
    ride = rides(:claimed_ride)
    ride.cancel!(actor: coordinators(:jane))

    assert_not_nil ride_claims(:acme_active_claim).reload.released_at
  end

  test "every transition writes a RideStatusEvent audit row with actor and timestamps" do
    ride = rides(:requested_ride)
    provider = transport_providers(:acme)

    ride.claim!(provider)

    event = ride.ride_status_events.order(:occurred_at).last
    assert_equal "requested", event.from_status
    assert_equal "claimed", event.to_status
    assert_equal provider, event.actor
    assert_not_nil event.occurred_at
  end
end
