require "test_helper"

class ProviderRanking::ReliabilityScoreTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "a provider with no resolved ride history gets the neutral default" do
    provider = TransportProvider.create!(name: "Brand New Co", phone: "555-0003")

    assert_equal ProviderRanking::ReliabilityScore::DEFAULT_SCORE, ProviderRanking::ReliabilityScore.call(provider)
  end

  test "blends completion rate and on-time-start rate from real ride history" do
    provider = TransportProvider.create!(name: "Track Record Co", phone: "555-0004")

    on_time_ride = book_ride(scheduled_at: 1.hour.from_now)
    on_time_ride.claim!(provider)
    travel_to(on_time_ride.scheduled_at - 5.minutes) { on_time_ride.start!(actor: provider) }
    on_time_ride.complete!(actor: provider)

    late_ride = book_ride(scheduled_at: 1.hour.from_now)
    late_ride.claim!(provider)
    travel_to(late_ride.scheduled_at + 30.minutes) { late_ride.start!(actor: provider) }
    late_ride.complete!(actor: provider)

    cancelled_ride = book_ride(scheduled_at: 1.hour.from_now)
    cancelled_ride.claim!(provider)
    cancelled_ride.cancel!(actor: coordinators(:jane))

    # completion_rate = 2 completed / 3 resolved = 0.667
    # on_time_rate = 1 on-time / 2 completed-with-a-start = 0.5
    # score = 0.667 * 0.6 + 0.5 * 0.4 = 0.6
    assert_in_delta 0.6, ProviderRanking::ReliabilityScore.call(provider), 0.01
  end

  private

  def book_ride(scheduled_at:)
    Ride.create!(
      patient: patients(:pat), coordinator: coordinators(:jane),
      pickup_address_line1: "1 Main St", pickup_city: "Springfield", pickup_state: "IL", pickup_zip: "62704",
      dropoff_address_line1: "2 Hospital Way", dropoff_city: "Springfield", dropoff_state: "IL", dropoff_zip: "62701",
      scheduled_at: scheduled_at, level_of_service: "wheelchair_van"
    )
  end
end
