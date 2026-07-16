require "test_helper"

class EligibilityCheckTest < ActiveSupport::TestCase
  test "covered service returns remaining trips and no prior auth" do
    response = EligibilityCheck.call(Fhir::EligibilityRequest.new(patient: patients(:pat), level_of_service: "wheelchair_van"))

    assert response.covered?
    # trip_limit is 10 on the wheelchair_coverage fixture; pat already has 4
    # non-cancelled wheelchair_van rides from other fixtures.
    assert_equal 6, response.remaining_trips
    assert_not response.prior_auth_required?
  end

  test "a service requiring prior auth still comes back covered, just flagged" do
    response = EligibilityCheck.call(Fhir::EligibilityRequest.new(patient: patients(:pat), level_of_service: "bls_ambulance"))

    assert response.covered?
    assert response.prior_auth_required?
  end

  test "a level_of_service with no coverage rule on the plan is not covered" do
    response = EligibilityCheck.call(Fhir::EligibilityRequest.new(patient: patients(:pat), level_of_service: "stretcher_van"))

    assert_not response.covered?
    assert_equal 0, response.remaining_trips
  end

  test "a patient with no benefit plan is not covered for anything" do
    response = EligibilityCheck.call(Fhir::EligibilityRequest.new(patient: patients(:ambulatory_amy), level_of_service: "medical_sedan"))

    assert_not response.covered?
  end
end
