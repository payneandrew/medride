require "test_helper"

# Fixture-backed tests run inside one wrapping transaction, so every query —
# even from a "different" thread using the same shared connection — would
# see the same uncommitted snapshot and never actually race. To prove the
# unique partial index (see 20260716184102_create_ride_claims.rb) serializes
# concurrent claims for real, this test turns off transactional fixtures and
# spins up genuinely separate database connections, then cleans up manually.
class RideClaimRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @organization = CareOrganization.create!(name: "Race Test Hospital", org_type: "hospital")
    @coordinator = @organization.coordinators.create!(name: "Race Coordinator", email: "race-#{SecureRandom.hex(4)}@example.com")
    @patient = Patient.create!(
      first_name: "Race", last_name: "Patient", phone: "555-0000",
      home_address_line1: "1 Race St", home_city: "Springfield", home_state: "IL", home_zip: "62704"
    )
    @provider_a = TransportProvider.create!(name: "Provider A", phone: "555-0001", service_area: [ "62704" ])
    @provider_b = TransportProvider.create!(name: "Provider B", phone: "555-0002", service_area: [ "62704" ])
    @ride = Ride.create!(
      patient: @patient, coordinator: @coordinator,
      pickup_address_line1: "1 Race St", pickup_city: "Springfield", pickup_state: "IL", pickup_zip: "62704",
      dropoff_address_line1: "2 Race Way", dropoff_city: "Springfield", dropoff_state: "IL", dropoff_zip: "62704",
      scheduled_at: 1.day.from_now, level_of_service: "rideshare"
    )
  end

  teardown do
    @ride.destroy
    [ @provider_a, @provider_b, @patient, @coordinator, @organization ].each(&:destroy)
  end

  test "two providers claiming the same ride at the same time: exactly one wins" do
    outcomes = Queue.new
    ready = Queue.new
    go = Queue.new

    # Each thread loads its own Ride object *before* the rendezvous, so both
    # independently observe status: requested (both pass can_claim?) before
    # either attempts to write — otherwise whichever thread happens to run
    # first can finish and commit before the second even reads, which would
    # make the Ruby-level guard reject the second claim instead of the
    # database. Holding both threads at `go.pop` until they're both ready
    # forces the actual INSERTs to contend for the unique index.
    threads = [ @provider_a, @provider_b ].map do |provider|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ride = Ride.find(@ride.id)
          ready << true
          go.pop
          outcomes << begin
            ride.claim!(provider)
            :claimed
          rescue Ride::AlreadyClaimedError
            :rejected
          end
        end
      end
    end

    2.times { ready.pop }
    2.times { go << true }
    threads.each(&:join)

    results = Array.new(2) { outcomes.pop }
    assert_equal %i[claimed rejected], results.sort
    assert_equal 1, RideClaim.where(ride: @ride, released_at: nil).count
  end
end
