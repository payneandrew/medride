require "test_helper"

class SmartOnFhir::AuthorizationRequestTest < ActiveSupport::TestCase
  test "standalone launch (no launch param) requests launch/patient scope" do
    result = SmartOnFhir::AuthorizationRequest.build(
      iss: "https://r4.smarthealthit.org",
      authorization_endpoint: "https://launch.smarthealthit.org/v/r4/auth/authorize",
      client_id: "medride-smart-demo",
      redirect_uri: "https://medride.example/smart/callback"
    )

    query = Rack::Utils.parse_query(URI.parse(result.url).query)

    assert_equal "code", query["response_type"]
    assert_equal "medride-smart-demo", query["client_id"]
    assert_includes query["scope"], "launch/patient"
    assert_not query.key?("launch")
    assert_equal result.state, query["state"]
    assert_equal "S256", query["code_challenge_method"]
  end

  test "EHR launch (launch param present) requests launch scope and echoes launch" do
    result = SmartOnFhir::AuthorizationRequest.build(
      iss: "https://r4.smarthealthit.org",
      authorization_endpoint: "https://launch.smarthealthit.org/v/r4/auth/authorize",
      client_id: "medride-smart-demo",
      redirect_uri: "https://medride.example/smart/callback",
      launch: "abc123"
    )

    query = Rack::Utils.parse_query(URI.parse(result.url).query)

    assert_equal "abc123", query["launch"]
    assert_includes query["scope"], "launch "
    assert_not_includes query["scope"], "launch/patient"
  end

  test "code_challenge is the correct SHA256/base64url digest of code_verifier" do
    result = SmartOnFhir::AuthorizationRequest.build(
      iss: "https://r4.smarthealthit.org",
      authorization_endpoint: "https://launch.smarthealthit.org/v/r4/auth/authorize",
      client_id: "medride-smart-demo",
      redirect_uri: "https://medride.example/smart/callback"
    )

    query = Rack::Utils.parse_query(URI.parse(result.url).query)
    expected_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(result.code_verifier), padding: false)

    assert_equal expected_challenge, query["code_challenge"]
  end

  test "state and code_verifier are unique per call" do
    build = -> {
      SmartOnFhir::AuthorizationRequest.build(
        iss: "https://r4.smarthealthit.org",
        authorization_endpoint: "https://launch.smarthealthit.org/v/r4/auth/authorize",
        client_id: "medride-smart-demo",
        redirect_uri: "https://medride.example/smart/callback"
      )
    }

    first = build.call
    second = build.call

    assert_not_equal first.state, second.state
    assert_not_equal first.code_verifier, second.code_verifier
  end
end
