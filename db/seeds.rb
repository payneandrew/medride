# Reference data for local development/demoing. Idempotent (find_or_create_by!)
# so it's safe to run more than once. Rides themselves aren't seeded here —
# see bin/ride_lifecycle_demo for a script that books and drives one through
# its full lifecycle, which is a better way to see the domain model in action
# than a static fixture row.

hospital = CareOrganization.find_or_create_by!(name: "Springfield General Hospital") { |o| o.org_type = "hospital" }
health_plan = CareOrganization.find_or_create_by!(name: "Wellness Health Plan") { |o| o.org_type = "health_plan" }

hospital.coordinators.find_or_create_by!(email: "jane.coordinator@springfieldgeneral.example") do |c|
  c.name = "Jane Coordinator"
end
health_plan.coordinators.find_or_create_by!(email: "mike.coordinator@wellnesshealthplan.example") do |c|
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

# Three providers with distinct, partly-overlapping zip coverage and
# capabilities, so MatchRide has something real to filter over.
springfield_transport = TransportProvider.find_or_create_by!(name: "Springfield Medical Transport") do |p|
  p.phone = "217-555-0101"
  p.service_area = %w[62701 62702 62703 62704]
end
[ "rideshare", "medical_sedan", "wheelchair_van" ].each do |capability|
  springfield_transport.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

milwaukee_nemt = TransportProvider.find_or_create_by!(name: "Milwaukee NEMT Co") do |p|
  p.phone = "414-555-0102"
  p.service_area = %w[53201 53202 53203]
end
[ "wheelchair_van", "stretcher_van" ].each do |capability|
  milwaukee_nemt.transport_provider_capabilities.find_or_create_by!(capability: capability)
end

metro_ambulance = TransportProvider.find_or_create_by!(name: "Metro Ambulance Services") do |p|
  p.phone = "800-555-0103"
  p.service_area = %w[62701 62704 53201]
end
[ "stretcher_van", "bls_ambulance" ].each do |capability|
  metro_ambulance.transport_provider_capabilities.find_or_create_by!(capability: capability)
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

Patient.find_or_create_by!(insurance_member_id: "MEDCAID-LOCAL-0001") do |p|
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

puts <<~SUMMARY
  Seeded:
    #{CareOrganization.count} care organizations, #{Coordinator.count} coordinators
    #{BenefitPlan.count} benefit plans, #{BenefitCoverageRule.count} coverage rules
    #{TransportProvider.count} transport providers, #{TransportProviderCapability.count} capabilities
    #{Patient.count} patients (FHIR-linked: #{Patient.where.not(fhir_id: nil).count})
SUMMARY
