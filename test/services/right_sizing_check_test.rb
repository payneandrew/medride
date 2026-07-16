require "test_helper"

class RightSizingCheckTest < ActiveSupport::TestCase
  test "allows a level_of_service at the patient's mobility ceiling" do
    assert RightSizingCheck.call(patient: patients(:pat), level_of_service: "wheelchair_van")
  end

  test "allows a level_of_service below the ceiling" do
    assert RightSizingCheck.call(patient: patients(:pat), level_of_service: "medical_sedan")
  end

  test "rejects a level_of_service above what mobility_needs requires" do
    assert_not RightSizingCheck.call(patient: patients(:pat), level_of_service: "bls_ambulance")
  end

  test "ambulatory patients are capped below wheelchair_van" do
    assert_not RightSizingCheck.call(patient: patients(:ambulatory_amy), level_of_service: "wheelchair_van")
  end
end
