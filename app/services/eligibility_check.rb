# Stands in for a live CoverageEligibilityRequest/Response round trip to a
# payer (in FHIR terms) without actually calling one — real-time eligibility
# checks are usually a paid, rate-limited X12/FHIR call, so this reads from
# the local benefit_plans/benefit_coverage_rules tables instead. The
# request/response shape (see app/services/fhir/eligibility_request.rb and
# eligibility_response.rb) is kept parallel to the real FHIR resources so
# swapping in a real payer integration later is a matter of replacing #call,
# not the interface.
class EligibilityCheck
  def self.call(request)
    new(request).call
  end

  def initialize(request)
    @request = request
  end

  def call
    rule = patient.benefit_plan&.coverage_rule_for(level_of_service)

    unless rule&.covered?
      return Fhir::EligibilityResponse.new(covered: false, remaining_trips: 0, prior_auth_required: false)
    end

    Fhir::EligibilityResponse.new(
      covered: true,
      remaining_trips: remaining_trips_for(rule),
      prior_auth_required: rule.prior_auth_required?
    )
  end

  private

  attr_reader :request

  def patient = request.patient
  def level_of_service = request.level_of_service.to_s

  def remaining_trips_for(rule)
    return nil if rule.trip_limit.nil? # unlimited

    used_trips = patient.rides.where(level_of_service: level_of_service).where.not(status: "cancelled").count
    [ rule.trip_limit - used_trips, 0 ].max
  end
end
