require "test_helper"

class SmartOnFhir::TokenExchangeTest < ActiveSupport::TestCase
  TOKEN_ENDPOINT = "https://launch.smarthealthit.org/v/r4/auth/token"

  test "exchanges a code for an access token and reads the patient launch context" do
    stub_request(:post, TOKEN_ENDPOINT)
      .with(body: hash_including(
        "grant_type" => "authorization_code",
        "code" => "auth-code-123",
        "code_verifier" => "verifier-abc",
        "redirect_uri" => "https://medride.example/smart/callback",
        "client_id" => "medride-smart-demo"
      ))
      .to_return(
        status: 200,
        body: {
          access_token: "swordfish-token",
          token_type: "Bearer",
          expires_in: 3600,
          patient: "smart-1288992",
          scope: "launch/patient patient/Patient.read"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = SmartOnFhir::TokenExchange.call(
      token_endpoint: TOKEN_ENDPOINT,
      code: "auth-code-123",
      code_verifier: "verifier-abc",
      redirect_uri: "https://medride.example/smart/callback",
      client_id: "medride-smart-demo"
    )

    assert_equal "swordfish-token", result.access_token
    assert_equal "smart-1288992", result.patient_id
    assert_equal 3600, result.expires_in
  end

  test "raises a SmartOnFhir::TokenExchange::Error when the server rejects the code" do
    stub_request(:post, TOKEN_ENDPOINT).to_return(
      status: 400,
      body: { error: "invalid_grant" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    assert_raises(SmartOnFhir::TokenExchange::Error) do
      SmartOnFhir::TokenExchange.call(
        token_endpoint: TOKEN_ENDPOINT,
        code: "bad-code",
        code_verifier: "verifier-abc",
        redirect_uri: "https://medride.example/smart/callback",
        client_id: "medride-smart-demo"
      )
    end
  end
end
