# Reference data — plus a full set of demo rides at the bottom — for local
# development. The reference data (orgs, plans, providers, patients) is
# idempotent (find_or_create_by!), safe to run more than once. The rides
# section is not: it only runs against an empty rides table (see the guard
# below), so re-running db:seed won't pile up duplicates, but it also won't
# "fix" ride data you've messed with by hand — reset the db first for that.

hospital = CareOrganization.find_or_create_by!(name: "Springfield General Hospital") { |o| o.org_type = "hospital" }
health_plan = CareOrganization.find_or_create_by!(name: "Wellness Health Plan") { |o| o.org_type = "health_plan" }

jane = hospital.coordinators.find_or_create_by!(email: "jane.coordinator@springfieldgeneral.example") do |c|
  c.name = "Jane Coordinator"
end
mike = health_plan.coordinators.find_or_create_by!(email: "mike.coordinator@wellnesshealthplan.example") do |c|
  c.name = "Mike Coordinator"
end

# Benefit plans stand in for real payer coverage tables: which
# level_of_service is covered, how many trips remain, and whether prior
# authorization is required — the fields EligibilityCheck reads.
basic_medicaid = BenefitPlan.find_or_create_by!(name: "Basic Medicaid")
{
  "rideshare" => { covered: true, trip_limit: nil, prior_auth_required: false },
  "medical_sedan" => { covered: true, trip_limit: 20, prior_auth_required: false },
  "wheelchair_van" => { covered: true, trip_limit: 20, prior_auth_required: false },
  "stretcher_van" => { covered: true, trip_limit: 6, prior_auth_required: false },
  "bls_ambulance" => { covered: true, trip_limit: 2, prior_auth_required: true }
}.each do |level_of_service, attrs|
  basic_medicaid.benefit_coverage_rules.find_or_create_by!(level_of_service: level_of_service) do |rule|
    rule.assign_attributes(attrs)
  end
end

premium_plan = BenefitPlan.find_or_create_by!(name: "Premium Health Plan")
{
  "rideshare" => { covered: true, trip_limit: nil, prior_auth_required: false },
  "medical_sedan" => { covered: true, trip_limit: nil, prior_auth_required: false },
  "wheelchair_van" => { covered: true, trip_limit: nil, prior_auth_required: false },
  "stretcher_van" => { covered: true, trip_limit: 12, prior_auth_required: false },
  "bls_ambulance" => { covered: true, trip_limit: 10, prior_auth_required: true }
}.each do |level_of_service, attrs|
  premium_plan.benefit_coverage_rules.find_or_create_by!(level_of_service: level_of_service) do |rule|
    rule.assign_attributes(attrs)
  end
end

# Three providers with distinct, partly-overlapping zip coverage,
# capabilities, dispatch bases, and pricing, so MatchRide/RankProviders
# have something real to filter and score over. base_lat/lng are each
# provider's dispatch base — how RankProviders' DistanceScore estimates
# proximity to a given pickup; rate_per_mile/base_fare feed PriceScore.
springfield_transport = TransportProvider.find_or_create_by!(name: "Springfield Medical Transport") do |p|
  p.phone = "217-555-0101"
  p.service_area = %w[62701 62702 62703 62704]
  p.base_lat = 39.7817 # downtown Springfield, IL
  p.base_lng = -89.6501
  p.base_fare_cents = 500
  p.rate_per_mile_cents = 200
end
[ "rideshare", "medical_sedan", "wheelchair_van" ].each do |capability|
  springfield_transport.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

milwaukee_nemt = TransportProvider.find_or_create_by!(name: "Milwaukee NEMT Co") do |p|
  p.phone = "414-555-0102"
  p.service_area = %w[53201 53202 53203]
  p.base_lat = 43.0389 # downtown Milwaukee, WI
  p.base_lng = -87.9065
  p.base_fare_cents = 600
  p.rate_per_mile_cents = 180
end
[ "wheelchair_van", "stretcher_van" ].each do |capability|
  milwaukee_nemt.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

metro_ambulance = TransportProvider.find_or_create_by!(name: "Metro Ambulance Services") do |p|
  p.phone = "800-555-0103"
  p.service_area = %w[62701 62704 53201]
  # A regional dispatch hub roughly between its IL and WI coverage, rather
  # than co-located with either — realistic for a multi-state ambulance
  # operator, and means it'll usually rank behind the local providers on
  # distance despite covering the same zips.
  p.base_lat = 41.8781 # Chicago, IL
  p.base_lng = -87.6298
  p.base_fare_cents = 1500
  p.rate_per_mile_cents = 400
end
[ "stretcher_van", "bls_ambulance" ].each do |capability|
  metro_ambulance.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

# Three more providers, each a direct competitor to one of the above on the
# same zips/capabilities but with a different base location and pricing —
# without real competition, RankProviders has nothing to rank (every
# claimable ride would have exactly one eligible provider).
prairie_capital = TransportProvider.find_or_create_by!(name: "Prairie Capital Transport") do |p|
  p.phone = "217-555-0104"
  p.service_area = %w[62701 62702 62703 62704]
  p.base_lat = 39.746 # south Springfield — same city as Springfield Medical Transport, different base
  p.base_lng = -89.653
  p.base_fare_cents = 400 # cheaper base fare...
  p.rate_per_mile_cents = 240 # ...but a pricier per-mile rate: cheaper for short trips, pricier for long ones
end
[ "rideshare", "medical_sedan", "wheelchair_van" ].each do |capability|
  prairie_capital.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

lakefront_medical = TransportProvider.find_or_create_by!(name: "Lakefront Medical Rides") do |p|
  p.phone = "414-555-0105"
  p.service_area = %w[53201 53202 53203]
  p.base_lat = 43.055 # Milwaukee's east side — competes directly with Milwaukee NEMT Co
  p.base_lng = -87.882
  p.base_fare_cents = 500
  p.rate_per_mile_cents = 220
end
[ "wheelchair_van", "stretcher_van" ].each do |capability|
  lakefront_medical.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

rapid_response = TransportProvider.find_or_create_by!(name: "Rapid Response EMS") do |p|
  p.phone = "217-555-0106"
  p.service_area = %w[62701 62702 62704]
  # Springfield-based, unlike Metro Ambulance's Chicago hub — closer and
  # cheaper, but (see its ride history below) less reliable. A real tradeoff,
  # not a strictly-better-or-worse competitor.
  p.base_lat = 39.79
  p.base_lng = -89.65
  p.base_fare_cents = 1200
  p.rate_per_mile_cents = 350
end
[ "stretcher_van", "bls_ambulance" ].each do |capability|
  rapid_response.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

# Not a marketplace participant: rides get sent to Uber Health via
# UberHealth::DispatchRide, not claimed through MatchRide, so its
# service_area is irrelevant and left empty. It still needs a row here
# since RideClaim#transport_provider has to point at *something*.
uber_health = TransportProvider.find_or_create_by!(name: "Uber Health") do |p|
  p.phone = "800-555-0199"
  p.service_area = []
end
UberHealth::Client::SUPPORTED_LEVELS_OF_SERVICE.each do |capability|
  uber_health.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

# Patients. Bruce Wayne, Ada Lovelace, and Sam Rivera are real records on
# the public HAPI FHIR test server (found by searching it during setup) —
# linked here via fhir_id so the "Import from EHR" flow has real patients to
# pull. The other one is local-only, representative of a patient who was
# hand-entered by a coordinator rather than imported.
bruce = Patient.find_or_create_by!(fhir_id: "137019620") do |p|
  p.first_name = "Bruce"
  p.last_name = "Wayne"
  p.phone = "+1-555-123-4567"
  p.home_address_line1 = "123 Main St"
  p.home_city = "Springfield"
  p.home_state = "IL"
  p.home_zip = "62701"
  p.mobility_needs = "wheelchair"
  p.insurance_member_id = "MEDCAID-137019620"
  p.benefit_plan = basic_medicaid
end

ada = Patient.find_or_create_by!(fhir_id: "137028282") do |p|
  p.first_name = "Ada"
  p.last_name = "Lovelace"
  p.phone = "555-0142"
  p.home_address_line1 = "123 Test Ave"
  p.home_city = "Milwaukee"
  p.home_state = "WI"
  p.home_zip = "53201"
  p.mobility_needs = "ambulatory"
  p.insurance_member_id = "PREMIUM-137028282"
  p.benefit_plan = premium_plan
end

sam = Patient.find_or_create_by!(fhir_id: "137028203") do |p|
  p.first_name = "Sam"
  p.last_name = "Rivera"
  p.phone = "555-0190"
  p.home_address_line1 = "44 Sunrise Rd"
  p.home_city = "Milwaukee"
  p.home_state = "WI"
  p.home_zip = "53202"
  p.mobility_needs = "stretcher"
  p.insurance_member_id = "MEDCAID-137028203"
  p.benefit_plan = basic_medicaid
end

dana = Patient.find_or_create_by!(insurance_member_id: "MEDCAID-LOCAL-0001") do |p|
  p.first_name = "Dana"
  p.last_name = "Local"
  p.phone = "217-555-0199"
  p.home_address_line1 = "77 Oak St"
  p.home_city = "Springfield"
  p.home_state = "IL"
  p.home_zip = "62703"
  p.mobility_needs = "bls_needed"
  p.benefit_plan = basic_medicaid
end

# Two more local-only patients, positioned near the new competing
# providers' bases (south Springfield / Milwaukee's east side) so their
# ride requests genuinely favor a different provider than Bruce's/Sam's do.
maria = Patient.find_or_create_by!(insurance_member_id: "PREMIUM-LOCAL-0002") do |p|
  p.first_name = "Maria"
  p.last_name = "Chen"
  p.phone = "217-555-0155"
  p.home_address_line1 = "2200 S MacArthur Blvd"
  p.home_city = "Springfield"
  p.home_state = "IL"
  p.home_zip = "62704"
  p.mobility_needs = "wheelchair"
  p.benefit_plan = premium_plan
end

marcus = Patient.find_or_create_by!(insurance_member_id: "MEDCAID-LOCAL-0003") do |p|
  p.first_name = "Marcus"
  p.last_name = "Webb"
  p.phone = "414-555-0166"
  p.home_address_line1 = "1555 N Prospect Ave"
  p.home_city = "Milwaukee"
  p.home_state = "WI"
  p.home_zip = "53202"
  p.mobility_needs = "stretcher"
  p.benefit_plan = basic_medicaid
end

# --- Rides ---------------------------------------------------------------
# Driven through the real Ride state machine methods (claim!/start!/
# complete!/cancel!), never raw status assignment, so RideClaim's
# active-claim invariant and RideStatusEvent's audit trail stay exactly as
# correct as they'd be from real usage. Timestamps are backdated afterward
# with update_columns purely for narrative realism — a ride "completed 2
# days ago" shouldn't have an audit trail dated the moment you ran this.
if Ride.none?
  def seed_ride!(patient:, coordinator:, pickup:, dropoff:, level_of_service:, scheduled_at:, provider: nil, dispatch_via_uber_health: false, outcome: :requested)
    eligibility = EligibilityCheck.call(Fhir::EligibilityRequest.new(patient: patient, level_of_service: level_of_service))

    ride = Ride.create!(
      patient: patient, coordinator: coordinator,
      pickup_address_line1: pickup[:line1], pickup_city: pickup[:city], pickup_state: pickup[:state], pickup_zip: pickup[:zip],
      pickup_lat: pickup[:lat], pickup_lng: pickup[:lng],
      dropoff_address_line1: dropoff[:line1], dropoff_city: dropoff[:city], dropoff_state: dropoff[:state], dropoff_zip: dropoff[:zip],
      dropoff_lat: dropoff[:lat], dropoff_lng: dropoff[:lng],
      scheduled_at: scheduled_at, level_of_service: level_of_service,
      needs_authorization: eligibility.prior_auth_required?
    )
    return ride if outcome == :requested

    if dispatch_via_uber_health
      UberHealth::DispatchRide.call(ride)
    else
      ride.claim!(provider)
    end
    return backdate_ride_events!(ride, scheduled_at: scheduled_at, outcome: outcome) if outcome == :claimed

    actor = ride.active_claim.transport_provider

    if outcome == :cancelled
      ride.cancel!(actor: actor)
      return backdate_ride_events!(ride, scheduled_at: scheduled_at, outcome: outcome)
    end

    ride.start!(actor: actor)
    return backdate_ride_events!(ride, scheduled_at: scheduled_at, outcome: outcome) if outcome == :in_progress

    ride.complete!(actor: actor)
    backdate_ride_events!(ride, scheduled_at: scheduled_at, outcome: outcome)
  end

  def backdate_ride_events!(ride, scheduled_at:, outcome:)
    events = ride.ride_status_events.reload.index_by(&:to_status)
    late = outcome == :completed_late

    events["requested"]&.update_columns(occurred_at: scheduled_at - 2.days)
    events["claimed"]&.update_columns(occurred_at: scheduled_at - 1.day)

    if events["in_progress"]
      started_at = late ? scheduled_at + 20.minutes : scheduled_at - 5.minutes
      events["in_progress"].update_columns(occurred_at: started_at)
      events["completed"]&.update_columns(occurred_at: started_at + 30.minutes)
    end

    events["cancelled"]&.update_columns(occurred_at: scheduled_at - 3.hours)

    ride
  end

  springfield_downtown = { line1: "700 E Adams St", city: "Springfield", state: "IL", zip: "62701", lat: 39.799, lng: -89.644 }
  springfield_clinic    = { line1: "701 N First St", city: "Springfield", state: "IL", zip: "62702", lat: 39.808, lng: -89.655 }
  springfield_facility  = { line1: "3140 Kavanaugh Rd", city: "Springfield", state: "IL", zip: "62704", lat: 39.766, lng: -89.673 }
  springfield_south     = { line1: "2200 S MacArthur Blvd", city: "Springfield", state: "IL", zip: "62704", lat: 39.749, lng: -89.653 }
  milwaukee_downtown    = { line1: "200 E Wells St", city: "Milwaukee", state: "WI", zip: "53202", lat: 43.041, lng: -87.907 }
  milwaukee_clinic      = { line1: "8701 W Watertown Plank Rd", city: "Milwaukee", state: "WI", zip: "53226", lat: 43.047, lng: -87.985 }
  milwaukee_eastside    = { line1: "1555 N Prospect Ave", city: "Milwaukee", state: "WI", zip: "53202", lat: 43.052, lng: -87.885 }

  # Bruce Wayne (wheelchair) x Springfield Medical Transport
  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 1.day.from_now.change(hour: 10),
    outcome: :requested) # unclaimed — shows up ranked under "Claimable rides"

  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 3.hours.from_now,
    provider: springfield_transport, outcome: :claimed) # claimed, not started — a ready target for firing test webhooks against

  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 1.hour.from_now,
    provider: springfield_transport, outcome: :in_progress)

  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 2.days.ago,
    provider: springfield_transport, outcome: :completed_on_time)

  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "medical_sedan", scheduled_at: 4.days.ago,
    provider: springfield_transport, outcome: :completed_late) # gives Springfield Medical Transport mixed (not perfect) reliability

  # Ada Lovelace (ambulatory) — Milwaukee NEMT Co only offers wheelchair/stretcher
  # vans, so a medical_sedan request has zero marketplace matches: the
  # "dispatch via Uber Health" fallback is the only path, by design.
  seed_ride!(patient: ada, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "medical_sedan", scheduled_at: 1.day.from_now.change(hour: 14),
    outcome: :requested)

  seed_ride!(patient: ada, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "rideshare", scheduled_at: 5.days.ago,
    dispatch_via_uber_health: true, outcome: :completed_on_time)

  # Sam Rivera (stretcher) x Milwaukee NEMT Co
  seed_ride!(patient: sam, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "stretcher_van", scheduled_at: 1.day.from_now.change(hour: 9),
    outcome: :requested)

  seed_ride!(patient: sam, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "stretcher_van", scheduled_at: 3.days.ago,
    provider: milwaukee_nemt, outcome: :completed_on_time)

  seed_ride!(patient: sam, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "stretcher_van", scheduled_at: 6.days.ago,
    provider: milwaukee_nemt, outcome: :cancelled) # gives Milwaukee NEMT Co a mixed completion rate too

  # Dana Local (bls_needed) x Metro Ambulance Services — bls_ambulance
  # requires prior auth on Basic Medicaid, so needs_authorization is true here.
  seed_ride!(patient: dana, coordinator: jane, pickup: springfield_facility, dropoff: springfield_clinic,
    level_of_service: "bls_ambulance", scheduled_at: 1.day.from_now.change(hour: 8),
    outcome: :requested)

  seed_ride!(patient: dana, coordinator: jane, pickup: springfield_facility, dropoff: springfield_clinic,
    level_of_service: "bls_ambulance", scheduled_at: 3.days.ago,
    provider: metro_ambulance, outcome: :completed_on_time)

  # --- History for the three newer competing providers, so their
  # reliability scores are real numbers, not everyone's shared 0.75 default.
  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 7.days.ago,
    provider: prairie_capital, outcome: :completed_on_time)
  seed_ride!(patient: bruce, coordinator: jane, pickup: springfield_downtown, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 11.days.ago,
    provider: prairie_capital, outcome: :completed_on_time) # perfect reliability — contrast against Springfield Medical Transport's 0.8

  seed_ride!(patient: sam, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "stretcher_van", scheduled_at: 5.days.ago,
    provider: lakefront_medical, outcome: :completed_on_time)
  seed_ride!(patient: sam, coordinator: mike, pickup: milwaukee_downtown, dropoff: milwaukee_clinic,
    level_of_service: "stretcher_van", scheduled_at: 9.days.ago,
    provider: lakefront_medical, outcome: :completed_late)

  seed_ride!(patient: dana, coordinator: jane, pickup: springfield_facility, dropoff: springfield_clinic,
    level_of_service: "bls_ambulance", scheduled_at: 5.days.ago,
    provider: rapid_response, outcome: :cancelled)
  seed_ride!(patient: dana, coordinator: jane, pickup: springfield_facility, dropoff: springfield_clinic,
    level_of_service: "bls_ambulance", scheduled_at: 9.days.ago,
    provider: rapid_response, outcome: :completed_on_time) # closer & cheaper than Metro Ambulance, but less reliable — a real tradeoff

  # --- More claimable rides, positioned so they actually contest between
  # two eligible providers instead of each ride having exactly one match.
  seed_ride!(patient: maria, coordinator: jane, pickup: springfield_south, dropoff: springfield_clinic,
    level_of_service: "wheelchair_van", scheduled_at: 1.day.from_now.change(hour: 11),
    outcome: :requested) # Springfield Medical Transport vs Prairie Capital Transport — this pickup favors Prairie on distance

  seed_ride!(patient: marcus, coordinator: mike, pickup: milwaukee_eastside, dropoff: milwaukee_clinic,
    level_of_service: "stretcher_van", scheduled_at: 1.day.from_now.change(hour: 13),
    outcome: :requested) # Milwaukee NEMT Co vs Lakefront Medical Rides — this pickup favors Lakefront on distance
end

puts <<~SUMMARY
  Seeded:
    #{CareOrganization.count} care organizations, #{Coordinator.count} coordinators
    #{BenefitPlan.count} benefit plans, #{BenefitCoverageRule.count} coverage rules
    #{TransportProvider.count} transport providers, #{TransportProviderCapability.count} capabilities
    #{Patient.count} patients (FHIR-linked: #{Patient.where.not(fhir_id: nil).count})
    #{Ride.count} rides (#{Ride.group(:status).count.map { |s, n| "#{n} #{s}" }.join(', ')})
SUMMARY
