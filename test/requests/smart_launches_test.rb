require "test_helper"

class SmartLaunchesTest < ActionDispatch::IntegrationTest
  ISS = "https://ehr.example.org/fhir"
  AUTHORIZE_ENDPOINT = "https://ehr.example.org/auth/authorize"
  TOKEN_ENDPOINT = "https://ehr.example.org/auth/token"

  setup do
    sign_in_as_coordinator!
    stub_smart_configuration!
  end

  test "requires a signed-in coordinator" do
    delete identity_path

    get smart_ehr_launch_path(iss: ISS, launch: "launch-xyz")

    assert_redirected_to new_identity_path
  end

  test "EHR launch redirects to the authorization endpoint with the launch param and launch scope" do
    get smart_ehr_launch_path(iss: ISS, launch: "launch-xyz")

    redirect_uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(redirect_uri.query)

    assert_equal "#{redirect_uri.scheme}://#{redirect_uri.host}#{redirect_uri.path}", AUTHORIZE_ENDPOINT
    assert_equal "launch-xyz", query["launch"]
    assert_includes query["scope"], "launch "
  end

  test "standalone launch redirects with no launch param and launch/patient scope" do
    post smart_launch_path, params: { iss: ISS }

    redirect_uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(redirect_uri.query)

    assert_not query.key?("launch")
    assert_includes query["scope"], "launch/patient"
  end

  test "callback exchanges the code, imports the FHIR patient, and lands on the new ride form" do
    get smart_ehr_launch_path(iss: ISS, launch: "launch-xyz")
    state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

    stub_token_exchange!
    stub_patient_fetch!

    assert_difference "Patient.count", 1 do
      get smart_callback_path(code: "auth-code-123", state: state)
    end

    patient = Patient.find_by(fhir_id: "smart-1288992")
    assert_equal "Ehr", patient.first_name
    assert_equal "Launch", patient.last_name
    assert_redirected_to new_ride_path(patient_id: patient.id)
  end

  test "callback rejects a mismatched state" do
    get smart_ehr_launch_path(iss: ISS, launch: "launch-xyz")

    assert_no_difference "Patient.count" do
      get smart_callback_path(code: "auth-code-123", state: "not-the-real-state")
    end

    assert_redirected_to new_smart_launch_path
  end

  private

  def sign_in_as_coordinator!
    post identity_path, params: { coordinator_id: coordinators(:jane).id }
  end

  def stub_smart_configuration!
    stub_request(:get, "#{ISS}/.well-known/smart-configuration")
      .to_return(
        status: 200,
        body: { authorization_endpoint: AUTHORIZE_ENDPOINT, token_endpoint: TOKEN_ENDPOINT }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_token_exchange!
    stub_request(:post, TOKEN_ENDPOINT).to_return(
      status: 200,
      body: {
        access_token: "swordfish-token",
        token_type: "Bearer",
        expires_in: 3600,
        patient: "smart-1288992"
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  def stub_patient_fetch!
    stub_request(:get, "#{ISS}/Patient/smart-1288992").to_return(
      status: 200,
      body: {
        resourceType: "Patient",
        id: "smart-1288992",
        name: [ { given: [ "Ehr" ], family: "Launch" } ],
        telecom: [ { system: "phone", value: "555-9999" } ],
        address: [ { line: [ "100 Launch Ave" ], city: "Boston", state: "MA", postalCode: "02115" } ],
        birthDate: "1990-01-01"
      }.to_json,
      headers: { "Content-Type" => "application/fhir+json" }
    )
  end
end
